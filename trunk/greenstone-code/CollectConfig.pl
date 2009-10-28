#this script outputs a config file for FoC collection

use strict;
use DBI;

if(@ARGV !=1){
	print "Usage:\n";
	print "Perl CollectConfig.pl outputfilepath\n";
	exit(1);
}

my $database = "focv22_corpus";
my $host = "localhost";
my $user = "termsuser";
my $password = "termspassword";
my $dbh = DBI->connect("DBI:mysql:host=$host", $user, $password)
or die DBI->errstr."\n";


my $query = $dbh->prepare('use '.$database) or die $dbh->errstr."\n";
$query->execute() or die $query->errstr."\n";

$query = $dbh->prepare('select distinct(modifier, tag) from sentence');
$query->execute() or die $query->errstr."\n";

my $index ="";
while(my($modifier, $tag) = $query->fetchrow_array()){
	my $label = $modifier." ".$tag;
	$label =~ s#\s+#-#g;
	$index .=$label." ";
}
chop($index);


#INDEXES: martt.gametophytes^branchlet martt.gametophytes^leaves
my $output = "creator       hongcui at email dot arionza dot edu";
$output.="

maintainer    hongcui at email.arizona.edu
public        true

searchtype    plain form

#indexes    document:text document:Title document:Source
indexes        allfields INDEXES
levels        document section
#defaultindex    document:text

classify    Hierarchy -metadata martt.taxon -buttonname Taxon

plugin        GAPlug
plugin        HTMLPlug -description_tags -cover_image
plugin        ArcPlug
plugin        RecPlug -use_metadata_files

format DateList \"<td>[link][icon][/link]</td>
<td>[highlight]{Or}{[dls.Title],[dc.Title],[ex.Title],Untitled}[/highlight]</td>
<td>[ex.Date]</td>\"

format HList \"[link][highlight]{Or}{[dls.Title],[dc.Title],[ex.Title],Untitled}[/highlight][/link]\"

format VList \"<td valign=top>[link][icon][/link]</td>
<td valign=top>[ex.srclink]{Or}{[ex.thumbicon],[ex.srcicon]}[ex./srclink]</td>
<td valign=top>[highlight]
{Or}{[dls.Title],[dc.Title],[ex.Title],Untitled}
[/highlight]{If}{[ex.Source],<br><i>([ex.Source])</i>}</td>\"

format DocumentText \"<h3>[Title]</h3>\\n\\n<p>[Text]\"
format DocumentImages true
format DocumentButtons \"Expand Text|Expand Contents|Detach|Highlight\"

format SearchVList \"<td valign=top>[link][icon][/link]</td><td>{If}{[parent(All\': \'):Title],[parent(All\': \'):Title]:}[link][Title][/link]</td>\"

collectionmeta    .document:text [l=en] \"text\"
collectionmeta    .document:Title [l=en] \"titles\"
collectionmeta    .document:Source [l=en] \"filenames\"
collectionmeta    .section [l=en] \"Element\"
collectionmeta    collectionname [l=en] \"FOC\"
collectionmeta    collectionextra [l=en] \"This collection contains plant descriptions from the published volumes of FOC. The descriptions were marked up automatically using the unsupervised markup algorithm developed by hongcui at email.arizona.edu. \"
collectionmeta    iconcollectionsmall [l=en] \"_httpprefix_/collect/foc/images/en/focsm.gif\"
collectionmeta    iconcollection [l=en] \"_httpprefix_/collect/foc/images/en/foc.gif\"
";

$output =~ s#INDEXES#$index#;

my @elements = split(/\s+/, $index);
foreach my $e (@elements){
	my $es = $e;
	$es =~ s#-# #g;
	$output .= "collectionmeta    .martt.$e [l=en] \"$es\"\n";
}
 
$output .= "collectionmeta    .allfields [l=en] \"all fields\"";

open(OUT, ">$ARGV[0]")||die "$! $ARGV[0]\n";
print OUT $output;
 


