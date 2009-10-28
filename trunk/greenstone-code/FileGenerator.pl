use DBI;

#this script read sentence table and taxon table (produced by FNA parser) and output files in greenstone format
#the taxon table provides nomenclature information for files in sentence table

#original document: f_RANUNCULACEAE_g_ANEMONE_s_edwardsiana_var.petraea.html:

#Achenes varnished, glabrous.

#marked-up document:
#<description>
#<taxon>Anemone edwardsiana var. petraea</taxon>
#<fruits><fruit-general>Achenes varnished, glabrous.</fruit-general></fruits>
#</description>


#greenstone file format:
#each pair of title and content must be enclosed by <Description>, which in turn is enclosed by <!--<Section>-->, Sections may be nested. More than one sections may be included.

#<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
#<html> <head> <title>an example</title> </head>
#<body>


#<!-- <Section>
#       <Description>
#            <Metadata name="Title">RANUNCULACEAE ANEMONE edwardsiana petraea</Metadata>
#            <Metadata name="martt.taxon">RANUNCULACEAE|ANEMONE|edwardsiana|petraea</Metadata>
#       </Description>-->
#       <!-- <Section>
#            <Description>
#                <Metadata name="martt.fruits"> Achenes varnished, glabrous. </Metadata>
#                <Metadata name="Title">fruits</Metadata>
#            </Description> -->
#            <!-- <Section><Description>
#                        <Metadata name="martt.fruits^fruit-general">Achenes varnished, glabrous.</Metadata>
#                        <Metadata name="Title">fruit general</Metadata>
#                        </Description> -->Achenes varnished, glabrous.
#            <!-- </Section> -->
#        <!-- </Section> -->
#<!-- </Section> -->


#</body></html>

if(@ARGV !=1){
	print "Usage:\n";
	print "Perl FileGenerator outputfolder\n";
	exit(1);
}

if(! -e "$ARGV[1]"){
	mkdir($ARGV[1]);
}
my $database = "focv22_corpus";
my $host = "localhost";
my $user = "termsuser";
my $password = "termspassword";
my $dbh = DBI->connect("DBI:mysql:host=$host", $user, $password)
or die DBI->errstr."\n";


my $query = $dbh->prepare('use '.$database) or die $dbh->errstr."\n";
$query->execute() or die $query->errstr."\n";

$query = $dbh->prepare('select source, modifier, tag, originalsent from sentence');
$query->execute() or die $query->errstr."\n";

my $header = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"><html> <head> <title>TAXON</title> </head>
<body>\n";
my $footer = "</body></html>";
my $TAXON ="";
my $pfile = "1.txt";
while(my ($sourcecopy, $modifier, $tag, $sent) = $query->fetchrow_array()){
	my $file = $sourcecopy;
	my $nom ="";
	my $sections ="";
	$file =~ s#-.*##;
	if($file ne $pfile){
		output($nom, $sections, $pfile);
		$pfile = $file;
		$nom = "";
		$sections = "";
	}else{
		$nom = extractName($file) if $nom eq "";
		$sections .=makeSection($modifier, $tag, $sent)."\n";
	}
}


sub output{
	my ($nom, $section, $file) = @_;
	$header =~ s#TAXON#$TAXON#;
	my $final = $header.$nom.$sections."<!-- </Section> -->".$footer;
	$file =~ s#\..*$#.html#g;
	
	open(OUT, ">$ARGV[0]\$file")||die "$! $ARGV[0]\n";
	print OUT $final;
}

#<!-- <Section>
#<Description>
#            <Metadata name="Title">RANUNCULACEAE ANEMONE edwardsiana petraea</Metadata>
#            <Metadata name="martt.taxon">RANUNCULACEAE|ANEMONE|edwardsiana|petraea</Metadata>
#       </Description>-->
sub extractName{
	my $file = shift;
	my $filenumber = $file;
	$filenumber =~ s#.txt##;
	my $query = $dbh->prepare('select name, rank from taxon where filenumber = '.$filenumber);
	$query->execute() or die $query->errstr."\n";
	my ($name, $rank) = $query->fetchrow_array();
	$TAXON = $name;
	my $taxon;
	if($rank=~/(species|variety|subgenus|genus|subspecies)/){#find tribe,subfamily, family name to form martt.taxon
		my $tribe = getTribe($filenumber); 
		my $subfamily = getSubfam($filenumber);
		my $family = getFam($filenumber);
		$taxon = generateTaxon($family, $subfamily, $tribe, $name);
	}elsif($rank=~/tribe/){#find subfamily, family name to form martt.taxon
		my $subfamily = getSubfam($filenumber);
		my $family = getFam($filenumber);
		$taxon = generateTaxon($family, $subfamily, $name);
	}elsif($rank=~/subfamily/){#find family name to form martt.taxon
		my $family = getFam($filenumber);
		$taxon = generateTaxon($family, $name);
	}else{
		$taxon = $family;
	}
	
	my $output = "<!-- <Section><Description><Metadata name=\"Title\">$name</Metadata><Metadata name=\"martt.taxon\">$taxon</Metadata></Description>-->\n";
	return $output;
}

sub getTribe{
	my $filenumber = shift;
	my $query = $dbh->prepare("select name from taxon where rank like  = '%tribe%' order by filenumber desc");
	$query->execute() or die $query->errstr."\n";
	my $name;
	if($query->rows() > 0){
		($name) = $query->fetchrow_array();
	}
	return $name;
}

sub getSubfam{
	my $filenumber = shift;
	my $filenumber = shift;
	my $query = $dbh->prepare("select name from taxon where rank like  = '%subfamily%' order by filenumber desc");
	$query->execute() or die $query->errstr."\n";
	my $name;
	if($query->rows() > 0){
		($name) = $query->fetchrow_array();
	}
	return $name;
	
}

sub getFam{
	my $filenumber = shift;
	my $filenumber = shift;
	my $query = $dbh->prepare("select name from taxon where rank like  = '%family%' order by filenumber desc");
	$query->execute() or die $query->errstr."\n";
	my $name;
	if($query->rows() > 0){
		($name) = $query->fetchrow_array();
	}
	return $name;
}

sub generateTaxon{
	my $saved = "START|END";
	for($i = 0; $i<@_; $i++){
		my $n = $_[$i];
		my @ns = split(/\s+/, $n);
		for($j = 0; $j <@ns; $j++){
			if($ns[$j] !=/\w/ && $ns[$j] !~/(var.|subsp.|subg.|sect.)/ && $ns[$j] !~/($saved)/){
				$saved =~ s#|#|$ns[$j]|#;	
			}
		}
	}
	$saved =~ s#START|##;
	$saved =~ s#|END##;
	return $saved;
}

#<!-- <Section><Description>
#                        <Metadata name="martt.fruits^fruit-general">Achenes varnished, glabrous.</Metadata>
#                        <Metadata name="Title">fruit general</Metadata>
#                        </Description> -->Achenes varnished, glabrous.
#            <!-- </Section> -->
sub makeSection{
	my ($modifier, $tag, $sent) = @_;
	my $title = $modifier." ".$tag;
	my $section = "<!-- <Section><Description>\n";
	$section .= "<Metadata name=\"martt.$title.\">$sent</Metadata>\n";
	$section .= "<Metadata name=\"Title\">$title</Metadata></Description> -->\n$sent<!-- </Section> -->\n";
	return $section;
}
