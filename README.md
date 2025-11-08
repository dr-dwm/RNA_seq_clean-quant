# RNA_seq_clean-quant
This is a snakemake pipeline which will take in raw RNAseq reads, filter them, remove the ribosomal rRNA and then align them to a salmon index. There is code on how to make your own salmon index in the supporting docs

The structure of the files needs to be as below
Working directory
> snakemake
> 01.RawData
  > Example_1.fq.gz
  > Example_2.fq.gz
> Salmon index
> envs
  > env_fastp.yaml
  > env_ribodetector.yaml
  > env_salmon.yaml

The current version of this only works on a HPCC environment where salmon is already installed, I will add a salmon.yaml file soon to allow this to be used without.

To create your index file (Add this as a module on its own that first checks if the index file is present and then if not generates it)

gffread -w *transcriptome.fa -g *_genome.fasta *_edited.gff3 # This step generates your transcriptome based on the whole genome.fasta file and a genome.gff3 file, which will need to be generated for your strain of interest (recommend bakta for this)

# generate a decoy file 
grep "^>" <S11_genome | cut -d " " -f 1 > decoys.txt
sed -i.bak -e 's/>//g' decoys.txt

# concatenating the transcriptome and genome reference
cat *transcriptome.fa *genome.fasta > *_for_index.fa

# build the index with the command below we use the gencode tag just in case any extra metadata is in there which is likely with GFF3
salmon index -t *_for_index.fa -d decoys.txt -p 12 -i salmon_index --gencode

# now we build the transcript index >>>> This is actually the same thing but the -k option can help in cases of low complexity or short sequences, supposedly the top option is more standard
salmon index -t S11_for_index.fa -i transcripts_index --decoys decoys.txt -k 31

# once generated your salmon_index file and put into the correct file structure you can run this pipeline by snakemake --use-conda --conda-frontend conda --cores 8 --printshellcmds which will filter, qc, remove rrna and build quant files which can directly be imported into r for Deseq2 analysis 









