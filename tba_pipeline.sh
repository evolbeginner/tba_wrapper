#! /bin/bash


#################################################################################
home_dir=`dirname $0`
split_fasta_prog=$home_dir/scripts/split_fasta.rb
maf_convert_prog=$home_dir/scripts/maf-convert.py

is_split_genome=true
is_force=false


#################################################################################
while [ $# -gt 0 ]; do
	case $1 in
		--core|--core_name|--corename)
			for corename in `echo $2|sed 's/,/ /g'`; do
				corenames=(${corenames[@]} $corename)
			done
			shift
			;;
		--genome_fasta)
			for genome_fasta in `echo $2|sed 's/,/ /g'`; do
				genome_fastas=(${genome_fastas[@]} $genome_fasta)
			done
			shift
			;;
		--no_split_genome)
			is_split_genome=false
			;;
		--split_fasta)
			split_fastas=(${split_fastas[@]} $2)
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--lastz_dir)
			for lastz_dir in `echo $2|sed 's/,/ /g'`; do
				lastz_dirs=(${lastz_dirs[@]} $lastz_dir)
			done
			shift
			;;
		--force)
			is_force=true
			;;
		*)
			echo "Unknown argument: $1. Exiting ......"
			exit 1
	esac
	shift
done


source $home_dir/scripts/set_EV.sh 
if [ -z $outdir ]; then
	echo "outdir has to be given! Exiting ......"
	exit 1
fi

if [ -d $outdir ]; then
	if $is_force; then
		rm -rf $outdir
	fi
fi
mkdir $outdir

split_fasta_dir=$outdir/split_fasta
nib_dir=$outdir/nib
psl_dir=$outdir/psl
chain_dir=$outdir/chain
net_dir=$outdir/net
faSize_dir=$outdir/faSize
axt_dir=$outdir/axt
maf_dir=$outdir/maf

mkdir -p $split_fasta_dir
mkdir -p $nib_dir
mkdir -p $psl_dir
mkdir -p $chain_dir
mkdir -p $net_dir
mkdir -p $faSize_dir
mkdir -p $axt_dir
mkdir -p $maf_dir


#################################################################################
for index in ${!genome_fastas[@]}; do
	genome_fasta=${genome_fastas[$index]}
	corename=${corenames[$index]}
	faSize $genome_fasta -detailed > $faSize_dir/$corename.faSize
	echo $genome_fasta
	if [ ${#split_fastas[*]} -eq ${#genome_fastas[*]} ]; then
		continue
	fi
	b=`basename $genome_fasta`
	genome_nib=${b/.fasta/.nib}
	genome_nib=${b/.fas/.nib}
	genome_nib=${b/.fa/.nib}
	#corename=${genome_nib%%.*}
	if $is_split_genome; then
		mkdir -p $split_fasta_dir/$corename
		ruby $split_fasta_prog -i $genome_fasta -n 1 --outdir $split_fasta_dir/$corename
		split_fastas=(${split_fastas[@]} $split_fasta_dir/$corename)
		if [ ${#corenames[@]} -lt ${#genome_fastas[@]} ]; then
			corenames=(${corenames[@]} $corename)
		fi
	fi
done


for index in ${!split_fastas[@]}; do
	i=${split_fastas[$index]}
	corename=`basename $i`
	if [ ! -d $split_fasta_dir/$corename ]; then
		cd `dirname $i` >/dev/null
		a=$PWD
		cd - >/dev/null
		cd $split_fasta_dir/ >/dev/null
		cp -rs $a/`basename $i` ./
		cd - >/dev/null
	fi
	if [ ${#corenames[@]} -lt ${#split_fastas[@]} ]; then
		corenames=(${corenames[@]} $corename)
	fi
done


# generate nib
for corename in ${corenames[@]}; do
	mkdir -p $nib_dir/$corename
	for i in $split_fasta_dir/$corename/*fas; do 
		faToNib $i ${i/.fas/.nib}
	done
	mv $split_fasta_dir/$corename/*nib $nib_dir/$corename
done


for lastz_dir in ${lastz_dirs[@]}; do
	b1=`basename $lastz_dir`
	[ ! -d $psl_dir/$b1 ] && mkdir $psl_dir/$b1
	for maf in $lastz_dir/*; do
		b2=`basename $maf`
		python $maf_convert_prog psl $maf > $psl_dir/${b1}/${b2/.maf/.psl}
	done
done


for psl_dir in $psl_dir/*; do
	query=`basename $psl_dir | cut -d "." -f 1 | cut -d "-" -f 1`
	target=`basename $psl_dir | cut -d "." -f 1 | cut -d "-" -f 2`
	b1=`basename $psl_dir`
	[ ! -d $chain_dir/$b1 ] && mkdir $chain_dir/$b1
	for psl in $psl_dir/*; do
		b2=`basename $psl`
		chain=${b2/.psl/.chain}
		axtChain -psl $psl $nib_dir/$query $nib_dir/$target $chain_dir/$b1/$chain -linearGap=loose
	done
done


# sort and filter the chains
for i in $chain_dir/*; do
	query=`basename $i | cut -d "." -f 1 | cut -d "-" -f 1`
	target=`basename $i | cut -d "." -f 1 | cut -d "-" -f 2`
	chainMergeSort $i/*.chain > $chain_dir/all.chain
	chainPreNet $chain_dir/all.chain $faSize_dir/$query.faSize $faSize_dir/$target.faSize $chain_dir/all.pre.chain
	chainNet $chain_dir/all.pre.chain -minSpace=1 $faSize_dir/$query.faSize $faSize_dir/$target.faSize stdout /dev/null | netSyntenic stdin $net_dir/noClass.net
	axt=$axt_dir/$query-$target.axt
	netToAxt $net_dir/noClass.net $chain_dir/all.pre.chain $nib_dir/$query $nib_dir/$target stdout | axtSort stdin $axt
	axtToMaf $axt $faSize_dir/$query.faSize $faSize_dir/$target.faSize $maf_dir/$query-$target.maf -tPrefix=$query. -qPrefix=$target.
done


