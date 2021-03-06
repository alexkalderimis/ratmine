#!/usr/bin/perl
# rgd-genes-to-xml.pl
# purpose: to create a target items xml file for intermine from RGD FTP file

#use warnings;
use strict;

BEGIN {
  push (@INC, ($0 =~ m:(.*)/.*:)[0] . '../intermine/perl/lib');
}

#use XML::Writer;
use InterMine::Item::Document;
use InterMine::Model;
#use InterMine::Util qw(get_property_value);
use IO qw(Handle File);
use Getopt::Long;
use Cwd;
use lib '../perlmods';
use RCM;
use ITEMHOLDER;


my ($model_file, $genes_file, $gene_xml, $help);
GetOptions( 'model=s' => \$model_file,
			'rgd_genes=s' => \$genes_file,
			'output_file=s' => \$gene_xml,
			'help' => \$help);

if($help or !($model_file and $genes_file))
{
	&printHelp;
	exit(0);
}

my $data_source = 'Rat Genome Database';
my $taxon_id = 10116;
my $output = new IO::File(">$gene_xml");
my $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 3, OUTPUT => $output);

# The item factory needs the model so that it can check that new objects have
# valid classnames and fields
my $model = new InterMine::Model(file => $model_file);
my $item_factory = new InterMine::Item::Document(model => $model);
$writer->startTag("items");

####
#User Additions
my $org_item = $item_factory->make_item('Organism');
$org_item->set('taxonId', $taxon_id);
$org_item->as_xml($writer);
my $dataset_item = $item_factory->make_item('DataSet');
$dataset_item->set('name', $data_source);
$dataset_item->as_xml($writer);

# read the genes file
open GENES, $genes_file;
my %index;
my $pub_items = ITEMHOLDER->new;
while(<GENES>)
{
	chomp;
	if( $_ !~ /^\d/) #parses header line
	{
		%index = &RCM::parseHeader($_)
	}
	else
	{
    #    print "\n   ------------ Line: ".$count."  --------------  \n";
		$_ =~ s/\026/ /g; #replaces 'Syncronous Idle' (Octal 026) character with space
		my @gene_info = split(/\t/, $_);
		my @synonym_items;
		my $gene_item = $item_factory->make_item('Gene');
		$gene_item->set('organism', $org_item);
		$gene_item->set('dataSets', [$dataset_item]);
		$gene_item->set('primaryIdentifier', $gene_info[$index{GENE_RGD_ID}]);
		$gene_item->set('secondaryIdentifier', $gene_info[$index{GENE_RGD_ID}]); #add RGD: to number
		$gene_item->set('symbol', $gene_info[$index{SYMBOL}]);
		$gene_item->set('name', $gene_info[$index{NAME}]) unless ($gene_info[$index{NAME}] eq '');	
		$gene_item->set('description', $gene_info[$index{GENE_DESC}]) unless ($gene_info[$index{GENE_DESC}] eq '');
		unless ($gene_info[$index{ENTREZ_GENE}] eq '' or $gene_info[$index{GENE_TYPE}] =~ /splice|allele/i)
		{
			$gene_item->set('ncbiGeneNumber', $gene_info[$index{ENTREZ_GENE}]);
			my $syn_item = $item_factory->make_item('Synonym');
			$syn_item->set('value', $gene_info[$index{ENTREZ_GENE}]);
			$syn_item->set('subject', $gene_item);
			$syn_item->as_xml($writer);
		}
		$gene_item->set('geneType', $gene_info[$index{GENE_TYPE}]) unless ($gene_info[$index{GENE_TYPE}] eq '');
		unless ($gene_info[$index{ENSEMBL_ID}] eq '')
		{
			#$gene_item->set('ensemblIdentifier', $gene_info[$index{ENSEMBL_ID}]);
			my %ensemblIds;
			foreach my $e (split(',', $gene_info[$index{ENSEMBL_ID}]))
			{
				next if (exists $ensemblIds{$e});
				my $syn_item = $item_factory->make_item('Synonym');
				$syn_item->set('value', $e);
				$syn_item->set('subject', $gene_item);
				$syn_item->as_xml($writer);
				$ensemblIds{$e} = 1;
			}
		}
		$gene_item->set('nomenclatureStatus', $gene_info[$index{NOMENCLATURE_STATUS}]) unless ($gene_info[$index{NOMENCLATURE_STATUS}] eq '');
		$gene_item->set('fishBand', $gene_info[$index{FISH_BAND}]) unless ($gene_info[$index{FISH_BAND}] eq '');
		
		unless($gene_info[$index{CURATED_REF_PUBMED_ID}] eq '')
		{
			my @curPubs;
			foreach my $pId (split(",", $gene_info[$index{CURATED_REF_PUBMED_ID}]))
			{
				unless( $pub_items->holds($pId) )
				{
					my $pub = $item_factory->make_item('Publication');
					$pub->set('pubMedId', $pId);
					$pub_items->store($pId, $pub);
				}
				push( @curPubs, $pub_items->get($pId) );
			}
			$gene_item->set('publications', \@curPubs);
		}
		
		$gene_item->as_xml($writer);
	} #end if-else	

}#end while
close GENES;
$pub_items->as_xml($writer);

$writer->endTag("items");

###Subroutintes###

sub printHelp
{
	print <<HELP;

perl rgd-genes-to-xml.pl 

Purpose:
Convert the GENES_RAT file from RGD into InterMine XML

Arguments:
 --model		Mine model file
 --rgd_genes		GENES_RAT file from RGD FTP site
 --output_file		InterMine XML file 
 --help			Print this message
HELP
}