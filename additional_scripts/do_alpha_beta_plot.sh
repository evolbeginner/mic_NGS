#! /usr/bin/env bash


###################################################
source ~/tools/self_bao_cun/packages/bash/util.sh


###################################################
indir=''
tax=S
matedata_file=''
is_force=false


###################################################
while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indir=$2
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--force)
			is_force=true
			;;
		--level)
			tax=$2
			shift
			;;
		--metadata)
			metadata_file=$2
			shift
			;;
	esac
	shift
done


###################################################
if [ "$metadata_file" == "" ]; then
	echo "metadata file has to be given! Exiting ......" >&2
	exit 1
fi


###################################################
mkdir_with_force $outdir $is_force


###################################################
for infile in $indir/*; do

	c=`cn $infile`
	abspath=`realpath $infile`
	suboutdir=$outdir/$c
	mkdir_with_force $suboutdir

	Rscript ~/software/NGS/EasyMicrobiome/script/otutab_rare.R --input $abspath --depth 0 --seed 1 --normalize $suboutdir/bracken.norm --output $suboutdir/bracken.alpha

	for i in richness chao1 ACE shannon simpson invsimpson; do
		Rscript ~/software/NGS/EasyMicrobiome/script/alpha_boxplot.R -i $suboutdir/bracken.alpha -a ${i} -d $metadata_file -n Group -w 89 -e 59 -o $suboutdir/alpha.
	done

	# Beta
	~/software/NGS/EasyMicrobiome/linux/usearch -beta_div $suboutdir/bracken.norm -filename_prefix $suboutdir/beta.
	beta_algos=(bray_curtis euclidean jaccard manhatten)
	for dist in ${beta_algos[@]}; do
		echo "Rscript ~/software/NGS/EasyMicrobiome/script/beta_pcoa.R --input $suboutdir/beta.${dist}.txt --design $metadata_file --group Group --width 89 --height 59 --output $suboutdir/pcoa.${dist}.pdf"
		Rscript ~/software/NGS/EasyMicrobiome/script/beta_pcoa.R --input $suboutdir/beta.${dist}.txt --design $metadata_file --group Group --width 89 --height 59 --output $suboutdir/pcoa.${dist}.pdf
	done

done


