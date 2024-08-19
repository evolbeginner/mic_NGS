#! /usr/bin/env ruby


##########################################################
dir = File.dirname(__FILE__)

BRACKEN = "conda run -n kraken2 bracken"
OTUTAB_RARE = "~/EasyMicrobiome/script/otutab_rare.R"
OTUTABLE_FROM_BRACKEN = File.join(dir, "additional_scripts", "otutable_from_bracken.rb")
DO_ALPHA_BETA_PLOT = File.join(dir, "additional_scripts", "do_alpha_beta_plot.sh")


##########################################################
require "getoptlong"
require "parallel"

require 'Dir'
require 'util'


##########################################################
indir = nil
infiles = Array.new
outdir = nil
is_force = false
cpu=2
metadata_file = nil


##########################################################
opts = GetoptLong.new(
  ["--indir", GetoptLong::REQUIRED_ARGUMENT],
  ["--bracken", GetoptLong::NO_ARGUMENT],
  ["--cpu", GetoptLong::REQUIRED_ARGUMENT],
  ["--metadata", "--meta", GetoptLong::REQUIRED_ARGUMENT],
  ["--outdir", GetoptLong::REQUIRED_ARGUMENT],
  ["--force", GetoptLong::NO_ARGUMENT]
)

opts.each do |opt, value|
	case opt
    when "--indir"
      indir = value
    when "--bracken"
      is_bracken = true
    when "--cpu"
      cpu = value.to_i
    when '--metadata', '--meta'
      metadata_file = value
    when '--outdir'
      outdir = value
    when '--force'
      is_force = true
  end
end

infiles = read_infiles(indir)
mkdir_with_force(outdir, is_force)
bracken_outdir = File.join(outdir, "bracken")
abundance_outdir = File.join(outdir, "abundance")
mkdir_with_force(bracken_outdir, is_force)
mkdir_with_force(abundance_outdir, is_force)


##########################################################
Parallel.map(infiles, in_threads:cpu) do |infile|
  c = getCorename(infile)
  outfile = File.join(bracken_outdir, c+".bracken")
  `#{BRACKEN} -d ~/software/NGS/kraken2/standard/ -i #{infile} -r 150 -l S -t 10 -o - -w #{outfile} 2>/dev/null`
end

`ruby #{OTUTABLE_FROM_BRACKEN} --indir #{bracken_outdir} --outdir #{abundance_outdir} --force --remove_euk --level S`

p "#{DO_ALPHA_BETA_PLOT} --indir #{abundance_outdir}/merged/ --outdir #{abundance_outdir}/alpha_beta --force --metadata #{metadata_file}"
`#{DO_ALPHA_BETA_PLOT} --indir #{abundance_outdir}/merged/ --outdir #{abundance_outdir}/alpha_beta --force --metadata #{metadata_file}`


