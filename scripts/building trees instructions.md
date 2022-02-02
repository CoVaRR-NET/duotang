## Running SARS-CoV-2 phylogenetic analysis

### 1. build dataset and make alignment
    - see readme "build CDN dataset for phylogenetic analyses" readme in 'scripts' folder in Notebook git repo
    - any focal/context dataset compilation needs to happen in this step



### 2. run IQ-tree to generate a ML tree

	Note iqtree:  - removes identical sequences, builds the tree, then adds them back in.
				  - doesn't allow sequences with identical headers
				  - will fail if there are too many gaps in some of the sequences (it'll tell you which seqs to remove)  

	local command:  

		iqtree -s alignment.fasta -m GTR -nt AUTO
	
	 This uses GTR as the model (-m forces it to use the model), other models used for SARS-CoV-2 are: GTR+I+R3 (includes invariant sites and discrete rate categories)
	 -nt or -T AUTO checks how to best use all available cores (don't use this for cluster runs)
	 note: Nextstrain uses this command:
	
		iqtree2 -ninit 2 -n 2 -me 0.05 -nt 4 -s alignment.fasta -m GTR -ninit 10 -n 4
		
	Note: if you want to run bootstraps add -B command:
	
		iqtree -s alignment.fasta -m GTR -nt AUTO -B 100
		
	- use -B for local computer, and -bb for the cluster
	- though this is "ultrafast" beware of very large trees, >100 BS will take a while
	- the bootstrap values (e.g. 0.85 or 85/100) are stored in the labels of the branches in the tree file
	- more on UFBoot and running iqtree in general see tutorial here: http://www.iqtree.org/doc/Tutorial
	- Also IQtree also offers other measures to evaluate concordance (e.g. gCF and sCF) see this tutorial on implementing and interpreting these measures:  http://www.robertlanfear.com/blog/files/concordance_factors.html
	- iqtree generates several output files, the tree is .treefile which is equivalent to a newick file
	


### 3. test resulting ML tree and remove overly divergent tips
	Remove any sequences that do not have complete dates (YY-MM-DD).  
	To remove sequences that are temporal outliers caused by sequencing errors:
	- load ML tree into Tempest http://tree.bio.ed.ac.uk/software/tempest/ (requires importing tab-delim sampling dates table)
	- select best-fitting root (heuristic residual mean squared)
	- to visually identify sequences: see residuals tab and highlight points beyond mean residual +/- 3SD, these are seen highlighted tips in the tree and often will be points in the root-to-tip that have ancestor traces into the 'future'. 
	- download Tempest data for this tree under 'File'
	- use Residuals dataset to identify outliers from mean, remove these tips from the ML tree, root tree in reference seq, and save (R script)  
	

### 4. run Tree Time (generates a ML time tree)

   Requires the ML tree, the alignment, and a dates table (with two columns: strain, date) that is tab-delim and corresponds to seq IDs in fasta and tree tips.  

   Local command:
   
      treetime --tree tree_file.nwk --aln alignment.fasta --dates dates.tsv --reroot IDofseq
   
   the --reroot function forces the root to be the sequence you designate (e.g. IDofseq =  "Wuhan/WIV04/2019")  
   Note: if you get any sequences "in the future" then these needed to be pruned in step 3. Remove them.
