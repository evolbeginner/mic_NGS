#! /usr/bin/env ruby


################################################
require "getoptlong"

require "Dir"
require "util"
require "Hash"


################################################
LEVEL2INDEX = {"G" => 7}
CONSISTENT_TAB = File.expand_path("~/tools/self_bao_cun/others/consistent_tab.rb")

indir = nil
is_remove_euk = false
levels = Array.new
outdir = nil
is_force = false


################################################
<<EOF
24.39	204	0	F	543	            Enterobacteriaceae
20.26	170	0	F1	2890311	              Klebsiella/Raoultella group
20.26	170	0	G	570	                Klebsiella
5.26	44	44	S	1463165	                  Klebsiella quasipneumoniae
11.14	93	93	S	573	                  Klebsiella pneumoniae
EOF

#  0.60	15	0	D	2759	    Eukaryota


################################################
opts = GetoptLong.new(
  ["--indir", GetoptLong::REQUIRED_ARGUMENT],
  ["--remove_euk", GetoptLong::NO_ARGUMENT],
  ["--level", GetoptLong::REQUIRED_ARGUMENT],
  ["--outdir", GetoptLong::REQUIRED_ARGUMENT],
  ["--force", GetoptLong::NO_ARGUMENT]
)

opts.each do |opt, value|
  case opt
    when '--indir'
      indir = value
    when '--outdir'
      outdir = value
    when '--level'
      levels << value.split(",")
    when '--force'
      is_force = true
    when '--remove_euk'
      is_remove_euk = true
  end
end

levels.flatten!


################################################
infiles = read_infiles(indir)
infiles.select!{|i| ! File.directory?(i) }

merged_outdir = File.join(outdir, "merged")
unmerged_outdir = File.join(outdir, "unmerged")
mkdir_with_force(merged_outdir, is_force)
mkdir_with_force(unmerged_outdir, is_force)


line_arr_h = Hash.new
infiles.each do |infile|
  in_fh = File.open(infile, 'r')
  lines = in_fh.readlines.map{|i|i.chomp}
  #p lines.map{|line| line[-1] =~ /^([ ][ ]){7}/}
  c = getCorename(infile)
  line_arrs = lines.map{|line| line.split("\t") }
  line_arr_h[c] = line_arrs
  in_fh.close
end


################################################
tax2abundance = multi_D_Hash(2)

line_arr_h.each_pair do |c, line_arrs|
  if is_remove_euk
    euk_index = line_arrs.find_index { |line_arr| line_arr[5] =~ /Eukaryota/ }
    line_arrs.slice!(euk_index..-1) if euk_index
  end

  levels.each do |level|
    case level
      when 'S'
        #line_arr[1]: abundance
        tax2abundance[c][level] = line_arrs.select{|line_arr| line_arr[5] =~ /^(\s+){16}(\S+ \S+.*)$/ }.map{ |line_arr| line_arr[5]=~/\s+(.+)/; [$1, line_arr[1]] }.to_h
      when 'G'
        index = LEVEL2INDEX[level]
        tax2abundance[c][level] = line_arrs.select{|line_arr| line_arr[5] =~ /^([ ][ ]){#{index}}(\S+)$/ }.map{ |line_arr| line_arr[5]=~/\s+(.+)/; [$1, line_arr[1]] }.to_h
    end
  end
end


################################################
tax2abundance.each_pair do |c, level_h|
  level_h.each do |level, v|
    outfile = File.join(outdir, 'unmerged', c + ".abundance-" + level)
    out_fh = File.open(outfile, 'w')
    v.each_pair do |tax, abundance|
      out_fh.puts [tax, abundance.sub(/^ +/,"")].join("\t")
    end
    out_fh.close
  end
end


levels.each do |level, v|
  outfile = File.join(merged_outdir, level + ".tsv")
  `#{CONSISTENT_TAB} --indir #{unmerged_outdir} | transpose.rb -i - > #{outfile} `
end


# S 9 spaces (but more importantly, spaces in bwtn the tax)
# G 7 spaces


