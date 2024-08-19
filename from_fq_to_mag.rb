#! /usr/bin/env ruby


#########################################
require_relative "lib/do_binning.rb"


#########################################
require 'parallel'
require 'getoptlong'

require 'Dir'


#########################################
MEGAHIT = "megahit"
#BOWTIE2 = "bowtie2"


#########################################
def prepare_add_arg(add_args)
  add_args[:megahit] = '--length_threshold 200'
  return(add_args)
end


def do_read_mapping(megahit_outdir, map_outdir, fqs, thread)
  contig = File.join(megahit_outdir, 'final.contigs.fa')
  mapping_outfile = File.join(map_outdir, 'map.out')
  to_sort_bam = File.join(map_outdir, 'to_sort.bam')
  sorted_bam = File.join(map_outdir, 'sorted.bam')
  depth_outfile = File.join(map_outdir, 'depth.txt')

  `bowtie2-build #{contig} #{megahit_outdir}/final.contigs --threads #{thread}`
  `bowtie2 -p #{thread} -x #{megahit_outdir}/final.contigs -1 #{fqs[0]} -2 #{fqs[1]} 2>#{mapping_outfile} |  samtools view -@ #{thread} -bS -o #{to_sort_bam}`
  `samtools sort -@ #{thread} #{to_sort_bam} -o #{sorted_bam}`
  `samtools index -@ #{thread} #{sorted_bam} >/dev/null`
  `rm #{to_sort_bam}`
  `jgi_summarize_bam_contig_depths --outputDepth #{depth_outfile} --referenceFasta #{contig} #{sorted_bam}`

  return(sorted_bam)
end


def do_MAG(tools:, cpu:, thread:, contig:, depth_file:, bins_outdir:, bam:, add_args:)
  Parallel.map(tools, in_threads:cpu) do |tool|
    puts ["starting", tool, Time.new.localtime].join(' ')
    outdir = File.join(bins_outdir, tool)
    case tool
      when 'metabat2'
        do_metabat2(thread:thread, contig:contig, depth_file:depth_file, outdir:outdir, add_arg:add_args[:metabat2])
      when 'concoct'
        do_concoct(thread:thread, contig:contig, outdir:outdir, bam:bam, add_arg:add_args[:concoct])
    end
  end
end


#########################################
fqs = Array.new
thread = 4
cpu = 2
outdir = nil
is_force = false
mag_tools = Array.new
megahit_indir = nil
stop_at = nil
is_fast = false

add_args = {:megahit => '', :metabat2 => '', :concoct => ''}


#########################################
opts = GetoptLong.new(
  ['-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--cpu', GetoptLong::REQUIRED_ARGUMENT],
  ['-p', '--thread', GetoptLong::REQUIRED_ARGUMENT],
  ['--mag_tool', GetoptLong::REQUIRED_ARGUMENT],
  ['--megahit_indir', GetoptLong::REQUIRED_ARGUMENT],
  ['--stop', '--stop_at', GetoptLong::REQUIRED_ARGUMENT],
  ['--fast', GetoptLong::NO_ARGUMENT],
  ['--outdir', GetoptLong::REQUIRED_ARGUMENT],
  ['--force', GetoptLong::NO_ARGUMENT]
)

opts.each do |opt, value|
  case opt
    when '-i'
      fqs << value.split(',')
    when '--cpu'
      cpu = value.to_i
    when '--thread', '--threads', '-p'
      thread = value.to_i
    when '--mag_tool'
      mag_tools << value.split(',')
    when '--megahit_indir'
      megahit_indir = value
    when '--stop', '--stop_at'
      stop_at = value
      puts "Warning: will stop at #{stop_at}!".colorize(:green)
      sleep 2
    when '--fast'
      is_fast = true
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
  end
end

fqs.flatten!
mag_tools.flatten!


#########################################
mkdir_with_force(outdir, is_force)

megahit_outdir = File.join(outdir, 'megahit_outdir')
map_outdir = File.join(megahit_outdir, 'mapping')
bins_outdir = File.join(outdir, 'bins_out')
`mkdir -p #{bins_outdir}`


#########################################
add_args = prepare_add_arg(add_args) if is_fast


#########################################
if megahit_indir.nil?
  megahit_outdir = File.join(outdir, 'megahit_outdir')
  puts "Starting megahit #{Time.new.localtime}"
  `#{MEGAHIT} -1 #{fqs[0]} -2 #{fqs[1]} -t #{thread} --preset meta-sensitive -o #{megahit_outdir} #{add_args[:megahit]} 2>/dev/null`
  `mkdir -p #{map_outdir}`
  sorted_bam = do_read_mapping(megahit_outdir, map_outdir, fqs, thread)
  contig = File.join(megahit_outdir, 'final.contigs.fa')
  depth_outfile = File.join(map_outdir, 'depth.txt')
else
  sorted_bam = File.join(megahit_indir, 'mapping', 'sorted.bam')
  contig = File.join(megahit_indir, 'final.contigs.fa')
  depth_outfile = File.join(megahit_indir, 'mapping', 'depth.txt')
end

if stop_at =~ /megahit|assembly/i
  puts "Stopping at assembly! Done. #{Time.new.localtime}" || exit
end


#########################################
do_MAG(tools:mag_tools, cpu:cpu, thread:thread, contig:contig, depth_file:depth_outfile, bins_outdir:bins_outdir, bam:sorted_bam, add_args:add_args)


