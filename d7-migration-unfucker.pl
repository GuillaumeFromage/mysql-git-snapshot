#!/usr/bin/perl

use warnings;
use feature 'signatures';
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
  # lets just yolo shall we
  @tables = ("history", "node_access", "node_comment_statistics", "node_revision", "search_node_link", "taxonomy_index"); 
  foreach $a (@tables)  {
    print "UPDATE IGNORE $a $d6db.node AS d6 JOIN node ON node.created=d6.created SET history.nid=d6.nid;\n";
  }
}

sub get_next_branch_name() {
  return $d7db . time();
}

sub init () {
  $new = 0; 
  if ($branch eq "<new!>") {
    $branchname = get_next_branch_name();
    $new = "1";
  } else {
    $branchname = $branch;
  }
  if (! -d $hackdir) {
    if ($debug) {
      print "initializing git repo of the database dumps through the steps of the upgrade";
    }
    mkdir($hackdir);
    chdir($hackdir);
    `git init .`;
    # https://stackoverflow.com/questions/11225105/is-it-possible-to-specify-branch-name-on-first-commit-in-git
    `git symbolic-ref HEAD refs/heads/$branchname`;
    commit_cur_state($auth, $mydumpopt, $d7db, "initial commit of the database before we intervene");
  } else {
    chdir($hackdir);
    if ($new) { 
      if ($debug) { 
        print "there is already a repo and we weren't specified a branch: creating $branchname\n\n";
      }
      `git branch $branchname`;
    } else {
      if ($debug) { 
        print "there is already a repo and we're going to the specific branch\n\n";
      }
      `git checkout $branchname`;
    }
    commit_cur_state($auth, $mydumpopt, $d7db, "initial commit of the database before we intervene");
  }  
    
}

$hackdir = "dbs";
$branch = "<new!>";

$debug = $d6db = $d7db = $deb = "";

GetOptions ('debug' => \$debug, 'd6db=s' => \$d6db, 'd7db=s' => \$d7db,'debian' => \$deb,)
  or usage();

if (!$deb) {
  print "you need to use --debian for db auth\n";
  exit();
} else { 
  $auth = "--defaults-file=/etc/mysql/debian.cnf";
}

$mydumpopt = "--extended-insert=FALSE";

if ($d6db eq "" or $d7db eq "") {
  usage();
  exit();
} 
init();

remap_nids();

