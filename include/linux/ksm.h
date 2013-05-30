#ifndef __LINUX_KSM_H
#define __LINUX_KSM_H
/*
 * Memory merging support.
 *
 * This code enables dynamic sharing of identical pages found in different
 * memory areas, even if they are not shared by fork().
 */

#include <linux/bitops.h>
#include <linux/mm.h>
#include <linux/pagemap.h>
#include <linux/rmap.h>
#include <linux/sched.h>

struct stable_node;
struct mem_cgroup;

struct page *ksm_does_need_to_copy(struct page *page,
			struct vm_area_struct *vma, unsigned long address);

#ifdef CONFIG_KSM
/*
 * A KSM page is one of those write-protected "shared pages" or "merged pages"
 * which KSM maps into multiple mms, wherever identical anonymous page content
 * is found in VM_MERGEABLE vmas.  It's a PageAnon page, pointing not to any
 * anon_vma, but to that page's node of the stable tree.
 */
static inline int PageKsm(struct page *page)
{
	return ((unsigned long)page->mapping & PAGE_MAPPING_FLAGS) ==
				(PAGE_MAPPING_ANON | PAGE_MAPPING_KSM);
}

static inline struct stable_node *page_stable_node(struct page *page)
{
	return PageKsm(page) ? page_rmapping(page) : NULL;
}

static inline void set_page_stable_node(struct page *page,
					struct stable_node *stable_node)
{
	page->mapping = (void *)stable_node +
				(PAGE_MAPPING_ANON | PAGE_MAPPING_KSM);
}

/* must be done before linked to mm */
extern inline void ksm_vma_add_new(struct vm_area_struct *vma);

extern void ksm_remove_vma(struct vm_area_struct *vma);
extern inline int unmerge_ksm_pages(struct vm_area_struct *vma,
				    unsigned long start, unsigned long end);

/*
 * When do_swap_page() first faults in from swap what used to be a KSM page,
 * no problem, it will be assigned to this vma's anon_vma; but thereafter,
 * it might be faulted into a different anon_vma (or perhaps to a different
 * offset in the same anon_vma).  do_swap_page() cannot do all the locking
 * needed to reconstitute a cross-anon_vma KSM page: for now it has to make
 * a copy, and leave remerging the pages to a later pass of ksmd.
 *
 * We'd like to make this conditional on vma->vm_flags & VM_MERGEABLE,
 * but what if the vma was unmerged while the page was swapped out?
 */
static inline int ksm_might_need_to_copy(struct page *page,
			struct vm_area_struct *vma, unsigned long address)
{
	struct anon_vma *anon_vma = page_anon_vma(page);

	return anon_vma &&
		(anon_vma != vma->anon_vma ||
		 page->index != linear_page_index(vma, address));
}

int page_referenced_ksm(struct page *page,
			struct mem_cgroup *memcg, unsigned long *vm_flags);
int try_to_unmap_ksm(struct page *page, enum ttu_flags flags);
int rmap_walk_ksm(struct page *page, int (*rmap_one)(struct page *,
		  struct vm_area_struct *, unsigned long, void *), void *arg);
void ksm_migrate_page(struct page *newpage, struct page *oldpage);

/* Each rung of this ladder is a list of VMAs having a same scan ratio */
struct scan_rung {
	struct list_head vma_list;
	//spinlock_t vma_list_lock;
	//struct semaphore sem;
	struct list_head *current_scan;
	unsigned int pages_to_scan;
	unsigned char round_finished; /* rung is ready for the next round */
	unsigned char busy_searched;
	unsigned long fully_scanned_slots;
	unsigned long scan_ratio;
	unsigned long vma_num;
	//unsigned long vma_finished;
	unsigned long scan_turn;
};

struct vma_slot {
	struct list_head ksm_list;
	struct list_head slot_list;
	unsigned long dedup_ratio;
	unsigned long dedup_num;
	int ksm_index; /* -1 if vma is not in inter-table,
				positive otherwise */
	unsigned long pages_scanned;
	unsigned long last_scanned;
	unsigned long pages_to_scan;
	struct scan_rung *rung;
	struct page **rmap_list_pool;
	unsigned long *pool_counts;
	unsigned long pool_size;
	struct vm_area_struct *vma;
	struct mm_struct *mm;
	unsigned long ctime_j;
	unsigned long pages;
	unsigned char need_sort;
	unsigned char need_rerand;
	unsigned long slot_scanned; /* It's scanned in this round */
	unsigned long fully_scanned; /* the above four to be merged to status bits */
	unsigned long pages_cowed; /* pages cowed this round */
	unsigned long pages_merged; /* pages merged this round */

	/* used for dup vma pair */
	struct radix_tree_root dup_tree;
};

/*
 * A few notes about the KSM scanning process,
 * to make it easier to understand the data structures below:
 *
 * In order to reduce excessive scanning, KSM sorts the memory pages by their
 * contents into a data structure that holds pointers to the pages' locations.
 *
 * Since the contents of the pages may change at any moment, KSM cannot just
 * insert the pages into a normal sorted tree and expect it to find anything.
 * Therefore KSM uses two data structures - the stable and the unstable tree.
 *
 * The stable tree holds pointers to all the merged pages (ksm pages), sorted
 * by their contents.  Because each such page is write-protected, searching on
 * this tree is fully assured to be working (except when pages are unmapped),
 * and therefore this tree is called the stable tree.
 *
 * In addition to the stable tree, KSM uses a second data structure called the
 * unstable tree: this tree holds pointers to pages which have been found to
 * be "unchanged for a period of time".  The unstable tree sorts these pages
 * by their contents, but since they are not write-protected, KSM cannot rely
 * upon the unstable tree to work correctly - the unstable tree is liable to
 * be corrupted as its contents are modified, and so it is called unstable.
 *
 * KSM solves this problem by several techniques:
 *
 * 1) The unstable tree is flushed every time KSM completes scanning all
 *    memory areas, and then the tree is rebuilt again from the beginning.
 * 2) KSM will only insert into the unstable tree, pages whose hash value
 *    has not changed since the previous scan of all memory areas.
 * 3) The unstable tree is a RedBlack Tree - so its balancing is based on the
 *    colors of the nodes and not on their contents, assuring that even when
 *    the tree gets "corrupted" it won't get out of balance, so scanning time
 *    remains the same (also, searching and inserting nodes in an rbtree uses
 *    the same algorithm, so we have no overhead when we flush and rebuild).
 * 4) KSM never flushes the stable tree, which means that even if it were to
 *    take 10 attempts to find a page in the unstable tree, once it is found,
 *    it is secured in the stable tree.  (When we scan a new page, we first
 *    compare it against the stable tree, and then against the unstable tree.)
 */


/**
 * node of either the stable or unstale rbtree
 *
 */
struct tree_node {
	struct rb_node node; /* link in the main (un)stable rbtree */
	struct rb_root sub_root; /* rb_root for sublevel collision rbtree */
	u32 hash;
	unsigned long count; /* how many sublevel tree nodes */
	struct list_head all_list; /* all tree nodes in stable/unstable tree */
};


/**
 * struct stable_node - node of the stable rbtree
 * @node: rb node of this ksm page in the stable tree
 * @hlist: hlist head of rmap_items using this ksm page
 * @kpfn: page frame number of this ksm page
 */
struct stable_node {
	struct rb_node node; /* link in sub-rbtree */
	struct tree_node *tree_node; /* it's tree node root in stable tree, NULL if it's in hell list */
	struct hlist_head hlist;
	unsigned long kpfn;
	u32 hash_max; /* if ==0 then it's not been calculated yet */
	//struct vm_area_struct *old_vma;
	struct list_head all_list; /* in a list for all stable nodes */
};




/**
 * struct node_vma - group rmap_items linked in a same stable
 * node together.
 */
struct node_vma {
	union {
		struct vma_slot *slot;
		unsigned long key;  /* slot is used as key sorted on hlist */
	};
	struct hlist_node hlist;
	struct hlist_head rmap_hlist;
	struct stable_node *head;
	unsigned long last_update;
};

/**
 * struct rmap_item - reverse mapping item for virtual addresses
 * @rmap_list: next rmap_item in mm_slot's singly-linked rmap_list
 * @anon_vma: pointer to anon_vma for this mm,address, when in stable tree
 * @mm: the memory structure this rmap_item is pointing into
 * @address: the virtual address this rmap_item tracks (+ flags in low bits)
 * @node: rb node of this rmap_item in the unstable tree
 * @head: pointer to stable_node heading this list in the stable tree
 * @hlist: link into hlist of rmap_items hanging off that stable_node
 */
struct rmap_item {
	struct vma_slot *slot;
	struct page *page;
	unsigned long address;	/* + low bits used for flags below */
	/* Appendded to (un)stable tree on which scan round */
	unsigned long append_round;

	/* Which rung scan turn it was last scanned */
	//unsigned long last_scan;
	unsigned long entry_index;
	union {
		struct {/* when in unstable tree */
			struct rb_node node;
			struct tree_node *tree_node;
			u32 hash_max;
		};
		struct { /* when in stable tree */
			struct node_vma *head;
			struct hlist_node hlist;
			struct anon_vma *anon_vma;
		};
	};
} __attribute__((aligned(4)));

struct rmap_list_entry {
	union {
		struct rmap_item *item;
		unsigned long addr;
	};
	// lowest bit is used for is_addr tag
	//unsigned char is_addr;
} __attribute__((aligned(4))); // 4 aligned to fit in to pages

//extern struct semaphore ksm_scan_sem;
#else  /* !CONFIG_KSM */

static inline int PageKsm(struct page *page)
{
	return 0;
}

#ifdef CONFIG_MMU

extern inline int unmerge_ksm_pages(struct vm_area_struct *vma,
				    unsigned long start, unsigned long end)
{
	return 0;
}

static inline int ksm_might_need_to_copy(struct page *page,
			struct vm_area_struct *vma, unsigned long address)
{
	return 0;
}

static inline int page_referenced_ksm(struct page *page,
			struct mem_cgroup *memcg, unsigned long *vm_flags)
{
	return 0;
}

static inline int try_to_unmap_ksm(struct page *page, enum ttu_flags flags)
{
	return 0;
}

static inline int rmap_walk_ksm(struct page *page, int (*rmap_one)(struct page*,
		struct vm_area_struct *, unsigned long, void *), void *arg)
{
	return 0;
}

static inline void ksm_migrate_page(struct page *newpage, struct page *oldpage)
{
}
#endif /* CONFIG_MMU */
#endif /* !CONFIG_KSM */

#endif /* __LINUX_KSM_H */
