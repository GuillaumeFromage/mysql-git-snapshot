#!/usr/bin/perl

use warnings;
use feature qw(switch say);
use Getopt::Long;
use feature 'signatures';

sub usage() {
    print <<USAGE
Usage: $0 --d6db asdf --d7db asdf --debian

This generates the sql to remap a lot of stuff into drupal7 from drupal6 ; trying to keep as much data sane
as possible;
USAGE
}

sub get_next_branch_name() {
  return $d7db . time();
}

sub dbdump {
  # whenever dump is called we assumed we're in the right directory and branch
  # which is set by init
  die "Too many arguments for subroutine" unless @_ <= 4;
  die "Too few arguments for subroutine" unless @_ >= 3;
  $auth = shift(@_);
  $opt = shift(@_);
  $db = shift(@_);
  $split = shift(@_) or 0;
  `mysqldump $auth $opt $db > $db.sql`;
  if ($debug) {
    print "dumped $db !\n\n"; 
  }
  # this part is from https://gist.github.com/jasny/1608062
  if ($split) {
    # this assumes that there is no table named table*
    `csplit -s -ftable $db.sql "/-- Table structure for table/" {*}`;
    `mv table00 AAAAhead.sql`;
    $last = `ls -1 table* | tail -n 1`;
    chomp($last);
    # print "csplit -b '%d' -s -f$last $last \"/40103 SET TIME_ZONE=\@OLD_TIME_ZONE/\" {*}";
    `csplit -b '%d' -s -f$last $last "/40103 SET TIME_ZONE=\@OLD_TIME_ZONE/" {*}`;
    `mv ${last}1 ZZZZfoot.sql`;
    @files = ();
    foreach $file (`ls -1 table*`) {
       chomp($file);
       $filename=`head -n1 $file | cut -d \\\`  -f2`; # https://xkcd.com/1638/
       chomp($filename);
       push(@files, $filename . ".sql");
       `cat AAAAhead.sql $file ZZZZfoot.sql > "$filename.sql"`;
    }
    `rm AAAAhead.sql ZZZZfoot.sql table*`;
    return @files;
  } else {
    return ("$db.sql"); 
  }

}

sub commit {
  $message = shift(@_);
  @files = @_;
  `git add @files`;
  `git commit -m "$message"`;
}

sub commit_cur_state ($auth, $opt, $db, $message) {
  commit($message, dbdump($auth, $opt, $db, 1));
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

sub remap_nids {
  # lets just yolo shall we
  @tables = ("history", "node_access", "node_comment_statistics", "node_revision", "search_node_link", "taxonomy_index"); 
  foreach $a (@tables)  {
    print "UPDATE IGNORE $a $d6db.node AS d6 JOIN node ON node.created=d6.created SET history.nid=d6.nid;\n";
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

