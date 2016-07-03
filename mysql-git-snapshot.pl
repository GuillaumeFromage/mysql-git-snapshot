#!/usr/bin/perl

use warnings;
use feature qw(switch say);
use Getopt::Long;

sub usage() {
    print <<USAGE
Usage: $0 --db database --debian [--branch branch] [--opt opts] [--dir directory] [--message message] [--ignore-tables tables] [--no-time] [--debug]

This just dumps a database in a git repo in a given directory and commits
it. 

 --debian	use login credentials from /etc/mysql/debian.cnf (if you don't
			us this you need to specify user, password and server which
			aren't implemented yet).
 --branch	which branch to commit to
 --debug	send more junk to stdout
 --message	the message for the commit
 --ignore-tables="table1,table2"	a bunch of tables to not drop
 --no-time	cut the lines that contain the time of the mysqldump, to 
			reduce to signal ratio

By default, it cuts up the database in individual table files, which can
just be cat'ed together to reload. Then you can git diff the different
tables during the process of doing something, and/or just re-enter some
part of the database.

USAGE
}

sub dbdump {
  # whenever dump is called we assumed we're in the right directory and branch
  # which is set by init
  die "Too few arguments for subroutine" unless @_ >= 3;
  $auth = shift(@_);
  $opt = shift(@_);
  $db = shift(@_);
  $split = shift(@_) or 0;
  @opts = @_;
  `mysqldump $auth $opt --extended-insert=FALSE $db > $db.sql`;
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
    foreach $del  (grep( /^deleteifexists:/, @opts )) {
      ($junk,$name) = split(":", $del);
      `git rm $name.sql`;
    }
    if ( grep( /^no-time$/, @opts ) ) {
      `grep -ve'-- Dump completed on' ${last}1 > ZZZZfoot.sql`;
      `rm ${last}1`;
      `cat ZZZZfoot.sql`;
    } else {
      `mv ${last}1 ZZZZfoot.sql`;
    }
    @files = ();
    foreach $file (`ls -1 table*`) {
       chomp($file);
       $filename=`head -n1 $file | cut -d \\\`  -f2`; # https://xkcd.com/1638/
       chomp($filename);
       push(@files, $filename . ".sql");
       `cat AAAAhead.sql $file ZZZZfoot.sql > "$filename.sql"`;
    }
    `rm AAAAhead.sql ZZZZfoot.sql table* $db.sql`;
    return @files;
  } else {
    return ("$db.sql"); 
  }

}

sub commit_cur_state {
  $dir = shift(@_);
  $branch = shift(@_);
  $auth = shift(@_);
  $opt = shift(@_);
  $db = shift(@_);
  $message = shift(@_);
  @opts = @_;
  if (! -d $dir) {
    if ($debug) {
      print "initializing git repo of the database dumps through the steps of the upgrade";
    }
    mkdir($dir);
  }
  chdir($dir);
  if (! -d '.git') {
    # not a git repo     
    `git init .`;
    if ($branch eq "master") {
      # https://stackoverflow.com/questions/11225105/is-it-possible-to-specify-branch-name-on-first-commit-in-git
      `git symbolic-ref HEAD refs/heads/$branch`;
    } 
  } else {
    `git checkout $branch`;
  }
  commit($message, dbdump($auth, $opt, $db, 1, @opts));
} 

sub commit {
  $msg = shift(@_);
  @files = @_;
  `git add @files`;
  `git commit -m "$msg"`;
}

$branch = 'master';
$message = 'mysql git snapshot autocommit ' . time();
$ignore_tables = $opt = $db = $directory = '';
$debug = $notime = $debian = 0;
@opts = ();
GetOptions ('db=s' => \$db, 'branch=s' => \$branch, 'opt=s' => \$opt, 'ignore-tables=s' => \$ignore_tables, 'debian' => \$debian, 'dir=s' => \$directory, 'message=s' => \$message,'no-time' => \$notime, 'debug' => \$debug)
  or usage();

if ($db eq '') {
   usage();
   exit();
}

if ($directory eq '') {
   $directory = $db;
}


if ($notime) {
  push(@opts, 'no-time');
} 

if ($ignore_tables) {
  # this is a bit useless, but kinda nice to not have to write 500 times the same string
  @ignored = split(',', $ignore_tables);
  foreach $table (@ignored) {
    $opt .= " --ignore-table=$db.$table ";
    push(@opts, "deleteifexists:$table");
  }
}   

if (!$debian ) {
  #TODO or if there is no other way of authing against the database server
  usage();
  exit();
} else {
  $auth = " --defaults-file=/etc/mysql/debian.cnf";
}

commit_cur_state($directory, $branch, $auth, $opt, $db, $message, @opts);
