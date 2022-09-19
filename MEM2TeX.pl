#!/usr/bin/perl -w
# Convert MEM Files to XeLaTeX
# MEM files are created by the typesetting program RUNOFF
# RNO files are used as input for the RUNOFF formatter
# by Roman Bartke <ed.fRoBoz@zoBoRf.de>
# Date: 2022-09-19
use strict;
use POSIX qw/strftime/;
use Getopt::Long;
use File::Basename;

my $version = "1.7";

my $ret = 0;
my $line;
my $next_line;
my $mark;
my @push_back;

my $fontdir = dirname(__FILE__)."/fonts/";
$fontdir =~ s/\\/\//ig;

my $header = <<'END_HEADER';
\documentclass[letterpaper]{article}

\usepackage[
pdfcreator={MEM2TeX.pl v#version#, XeLateX},
pdfcreationdate={D:#time#},
#pfi#]{hyperref}

% https://tex.stackexchange.com/questions/62311/a4paper-where-should-i-declare-it-in-document-class-or-geometry
\usepackage{geometry}
\geometry{letterpaper,margin=10mm,top=10mm,lmargin=20mm,bindingoffset=0mm,}

\usepackage{fontspec}
% https://github.com/JetBrains/JetBrainsMono/issues/59
\newfontfamily\jbmono{jetbrainsmono}[Path, 
    Extension=.ttf, 
    Contextuals={Alternate},
    NFSSFamily=jbmono,% Required for minted; see fontspec§4.2
    UprightFont = #fontdir#*-Regular,
    ItalicFont = #fontdir#*-Italic,
    BoldFont = #fontdir#*-Bold,
    BoldItalicFont = #fontdir#*-bold-italic,
    FontFace = {sb}{n}{#fontdir#*-medium},
    FontFace = {sb}{it}{#fontdir#*-medium-italic},
    FontFace = {eb}{n}{#fontdir#*-extrabold},
    FontFace = {eb}{it}{#fontdir#*-extrabold-italic}]

% https://alexwlchan.net/2017/10/latex-underlines/
\usepackage{ulem}
%\usepackage{soul}
% don't use soul package: problem with underlining words containing 
% hyphens (e.g. TOPS-20) the last character (here "0") will be missing
% in output.

\usepackage{fancyvrb}

% https://tex.stackexchange.com/questions/278494/forcing-a-page-break-in-verbatiminput-fancyvrb
\def^^L{\par} % not outer
\def\aftereject{\aftergroup\afterejectI}
\def\afterejectI{\aftergroup\pagebreak}

\pagestyle{empty}
\begin{document}

% https://tex.stackexchange.com/questions/116862/how-to-underline-text-in-verbatim-environment
\begin{Verbatim}[defineactive=\def^^L{\aftergroup\aftereject},fontfamily=jbmono,commandchars=§\[\]]
END_HEADER

my $footer = <<'END_FOOTER';
\end{Verbatim}
\end{document}
END_FOOTER

my $new_page_marker = "[^L]";
#my $ul = "§underline";
my $ul = "§uline";
my $bf = "§textbf";

my $file     = "";
my $pfi_file = "";
my $tex_file = "";

my $result = GetOptions("mem-file=s" => \$file,
			"pfi-file=s" => \$pfi_file,
			"tex-file=s" => \$tex_file);

if (!$result) {
	usage($0);
}
die "Missing input file (--mem-file)\n" unless $file;
# die "Missing output file (--tex-file)\n" unless $tex_file;

my $pfi = "";
if ($pfi_file ne "") {
	open(my $fh, '<', $pfi_file) or die "PFI-File: $pfi_file: $!\n";
	while ($next_line = <$fh>) {
		chomp $next_line;
		$pfi .= $next_line . "\n";
	}
	close $fh;
}

my $ts = strftime("%Y%m%d%H%M%S", gmtime(time));
$header =~ s/#time#/$ts/ig;
$header =~ s/#version#/$version/ig;
$header =~ s/#pfi#/$pfi/ig;
$header =~ s/#fontdir#/$fontdir/ig;

if ($tex_file ne "") {
	open(STDOUT, '>', $tex_file) or die "Output file: $tex_file: $!\n";
}
open(my $fh, '<', $file) or die "Input file: $file: $!\n";
print $header;
while ($next_line = <$fh>) {
	chomp $next_line;
	push @push_back, $next_line;
	while (scalar @push_back != 0)
	{
		$line = shift @push_back;
		if ($line =~ //) {
			my ($one, $two) = split(//, $line);
			if ($one ne "") {
				push @push_back, $one;
			}
			push @push_back, $new_page_marker;
			if ($two ne "") {
				push @push_back,  $two;
			}
			next;
		}
		if ($line =~ //) {
			$mark = "*";
			my (@lines) = split(//, $line);
			my $i = 0;
			my $max_length = MaxLength(@lines);
			foreach my $l (@lines) {
				$l = pad($l, $max_length);
			}
			if (underline_only($lines[1])) {
				@lines = reverse @lines;
			}
			my $text = "";
			my $attrib = "";
			for($i = 0; $i < $max_length; $i++) {
				my $cur = "";
				my $c = "";
				my $next = "";
				my $bold = 0;
				my $underline = 0;
				foreach(@lines) {
					my $underlineOnly = underline_only($_);
					$c = substr($_, $i, 1);
					if ($c ne " " && $c ne "_" && $cur eq "") {
						$cur = $c;
					} else {
						if ($c eq "_" && $underlineOnly) {
							$underline = 1;
						}
						if ($cur ne " " && $cur ne "" && $cur eq $c) {
							$bold = 1;
						} else {
							$cur = $c;
						}
					}
				}
				$text .= $cur;
				if ($bold && $underline) {
					$attrib .= "X";
				} elsif ($bold) {
					$attrib .= "B";
				} elsif ($underline) {
					$attrib .= "U";
				} else {
					$attrib .= " ";
				}
			}
			$i = 0;
			my $cur_attrib = " ";
			foreach my $a (split //, $attrib) {
				if ($cur_attrib eq " ") {
					if      ($a eq " ") {
					} elsif ($a eq "B") {
						print $bf."[";
					} elsif ($a eq "U") {
						print $ul."[";
					} elsif ($a eq "X") {
						print $bf."[".$ul."[";
					}
				} elsif ($cur_attrib eq "B") {
					if      ($a eq " ") {
						print "]";
					} elsif ($a eq "B") {
					} elsif ($a eq "U") {
						print "]".$ul."[";
					} elsif ($a eq "X") {
						print "]".$bf."[".$ul."[";
					}
				} elsif ($cur_attrib eq "U") {
					if      ($a eq " ") {
						print "]";
					} elsif ($a eq "B") {
						print "]".$ul."[";
					} elsif ($a eq "U") {
					} elsif ($a eq "X") {
						print "]".$bf."[".$ul."[";
					}
				} elsif ($cur_attrib eq "X") {
					if      ($a eq " ") {
						print "]]";
					} elsif ($a eq "B") {
						print "]]".$bf."[";
					} elsif ($a eq "U") {
						print "]]".$ul."[";
					} elsif ($a eq "X") {
					}
				}
				my $cur_char = substr($text, $i, 1);
				output_char($cur_char);
				$cur_attrib = $a;
				$i++;
			}
			if      ($cur_attrib eq " ") {
			} elsif ($cur_attrib eq "B") {
				print "]";
			} elsif ($cur_attrib eq "U") {
				print "]";
			} elsif ($cur_attrib eq "X") {
				print "]]";
			}
			print "\n";
		} else {
			$mark = " ";
			if ($line ne $new_page_marker) {
				foreach my $cur_char (split //, $line) {
					output_char($cur_char);
				}
				print "\n";
			} else {
				print "\n";
			}
		}
	}
}
print $footer;
close $fh;
close STDOUT;
exit $ret;

sub MaxLength {
	my $max = 0;
	my @lines = @_;
	foreach (@lines) {
		my $l = length($_);
		if ($l > $max) {
			$max = $l;
		}
	}
	return $max;
}

sub pad {
	my ($string, $length) = @_;
	my $pad_length = $length - length($string);
	return $string . " "x$pad_length;
} 

sub underline_only {
	my $line = shift;
	foreach my $c (split //, $line) {
		if ($c ne " " && $c ne "_") {
			return 0;
		}
	}
	return 1;
}

sub output_char {
	my $cur_char = shift;
	if ($cur_char eq "[") {
		print "§lbrack[]";
	} elsif ($cur_char eq "]") {
		print "§rbrack[]";
	} elsif (ord($cur_char) == 0) {
		# ignore ^@
	} else {
		print $cur_char;
	}
}

sub usage {
	my $me = basename(shift);
	print STDERR "$me Version $version\n";
	print STDERR "Usage: $me ...\n";
	print STDERR "           --filename:  input file name           \n";
	print STDERR "          [--pfi-file]: PDF file information file \n";
	print STDERR "          [--tex-file]: output XeLaTeX filename   \n";
	print STDERR "\n";
	print STDERR "Sample PDF file information file:                 \n";
	print STDERR "--------------------------------------------------\n";
	print STDERR "pdftitle={TOPS-20 LINK Reference Manual},         \n";
	print STDERR "pdfauthor={Digital Equipment Corporation},        \n";
	print STDERR "pdfsubject={TOPS-20 LINK},                        \n";
	print STDERR "pdfkeywords={AA-4183D-TM TOPS-20 LINK}	        \n";
	print STDERR "--------------------------------------------------\n";
	exit;
}
