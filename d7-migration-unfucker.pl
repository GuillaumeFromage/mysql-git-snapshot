#!/usr/bin/perl

use warnings;
use feature qw(switch say);
use Getopt::Long;

sub usage() {
    print <<USAGE
Usage: $0 --d6db asdf --d7db asdf --debian

This generates the sql to remap a lot of stuff into drupal7 from drupal6 ; trying to keep as much data sane
as possible;
USAGE
}

sub remap_nids {
  $db = shift(@_);
  $d6db = shift(@_);
  $auth = shift(@_);
  $debug = shift(@_);
  # lets just yolo shall we
  @tables = ("history", "node_access", "node_comment_statistics", "node_revision", "search_node_link", "taxonomy_index"); 
  foreach $a (@tables)  {
    `echo "UPDATE IGNORE $a JOIN $d6db.node AS d6 JOIN node ON node.created=d6.created SET nid=d6.nid;\n" | mysql $auth $db `;
    if ($debug) {    
      print "UPDATE IGNORE $a JOIN $d6db.node AS d6 JOIN node ON node.created=d6.created SET nid=d6.nid;\n" ;
    }
  }
  
}

sub get_next_branch_name {
  return $d7db . time();
}

sub find_mysql_git_snapshot {
  if (-f 'mysql-git-snapshot.pl') {
    # we found it !
    return './mysql-git-snapshot.pl';
  } else {
    return 0;
  }
}

sub init {
  $mgs = find_mysql_git_snapshot(); 
  if (!$mgs) {
     die("couldn't find mysql_git_snapshot :(\n");
  } 
  $new = 0; 
  print "$branch\n";
  if ($branch eq "<new!>") {
    $branchname = get_next_branch_name();
    $new = "1";
  } else {
    $branchname = $branch;
  }
  `$mgs --dir=$hackdir --message="d7-migration-unfucker first commit" --branch=$branchname --db=$d7db --debug --debian --no-time --ignore-tables='cache,cache_block,cache_bootstrap,cache_field,cache_filter,cache_form,cache_image,cache_menu,cache_page,cache_path,cache_update'`;
  return $mgs;
}

$hackdir = "dbs";
$branch = "master";

$debug = $d6db = $d7db = $deb = "";

GetOptions ('branch=s' => \$branch, 'debug' => \$debug, 'd6db=s' => \$d6db, 'd7db=s' => \$d7db,'debian' => \$deb,)
  or usage();

if (!$deb) {
  print "you need to use --debian for db auth\n";
  exit();
} else { 
  $auth = "--defaults-file=/etc/mysql/debian.cnf";
}

if ($d6db eq "" or $d7db eq "") {
  usage();
  exit();
} 

$mgs = init();

remap_nids($d7db, $d6db, $auth, $debug);
 
`$mgs --dir=$hackdir --message="after remapping the nids from the d6db" --branch=$branch --db=$d7db --debug --debian --no-time --ignore-tables='cache,cache_block,cache_bootstrap,cache_field,cache_filter,cache_form,cache_image,cache_menu,cache_page,cache_path,cache_update'`;
