#! /usr/bin/bash


############################################
# perform gtdbtk analysis w/ the option of either bac or archaea


############################################
source  ~/tools/self_bao_cun/packages/bash/util.sh
GTDBTK="mamba run -n gtdbtk2 gtdbtk"


############################################
ORGNS=(all full bacteria archaea)

indir=''
orgn='all'
ext='fa'
cpu=4
outdir=''
is_force=false


############################################
while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indir=$2
			shift
			;;
		--orgn)
			orgn=$2
			shift
			;;
		--ext|extension)
			ext=$2
			shift
			;;
		--cpu)
			cpu=$2
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--force)
			is_force=true
			;;
	esac
	shift
done


############################################
if [ $outdir == '' ]; then
	echo "outdir not specified! Exiting ......" >&2
	exit 1
fi

mkdir_with_force $outdir $is_force

if [[ "${ORGNS[@]/$orgn/}" == "${ORGNS[@]}" ]]; then
	echo "Wrong orgn $orgn. Exiting ......" >&2; exit 1
fi

if [ "$orgn" == bacteria ]; then orgn_abbr=bac120; elif [ "$orgn" == archaea ]; then orgn_abbr=ar53; fi


############################################
case $orgn in
	all|full)
		$GTDBTK classify_wf --skip_ani_screen --genome_dir $indir --out_dir $outdir --extension $ext --cpus $cpu
		;;

	bacteria|archaea)
		identify_outdir=$outdir/identify
		mkdir $identify_outdir
		align_outdir=$outdir/align
		mkdir $align_outdir
		classify_outdir=$outdir/classify
		mkdir $classify_outdir

		genome_outdir=$outdir/genome

		echo "Identifying ...... `date`"
		$GTDBTK identify --genome_dir $indir --out_dir $identify_outdir --cpus $cpu -x $ext > $identify_outdir/stdout
		echo "Aligning ...... `date`"
		$GTDBTK align --identify_dir $identify_outdir --out_dir $align_outdir --cpus $cpu > $align_outdir/stdout

		if [ "$orgn" == bacteria ]; then orgn_abbr=bac120; elif [ "$orgn" == archaea ]; then orgn_abbr=ar53; fi
		genomes=`zcat $outdir/align/align/gtdbtk.${orgn_abbr}.user_msa.fasta.gz | grep "^>" | sed 's/^>//'`

		mkdir $genome_outdir
		for i in ${genomes[@]}; do
			ln -s `realpath $indir/$i.$ext` $genome_outdir
		done
		if [ ${#genomes[@]} -eq 0 ]; then echo "No $orgn genomes."; fi
		echo "Classifying $orgn: ${#genomes[@]} genomes ...... `date`"
		$GTDBTK classify --skip_ani_screen --genome_dir $genome_outdir -x $ext --align_dir $align_outdir --out_dir $classify_outdir \
			--cpus $cpu > $classify_outdir/stdout
		;;
esac

echo "Done! `date`"


