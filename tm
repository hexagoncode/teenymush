#!/usr/bin/perl

use strict;
use IO::Select;
use IO::Socket;
use DBI;

# Any variables that need to survive a reload of code should be placed
# here. Variables that need to be accessed in other files may need to be
# placed here as well.

my (%command,                       # commands for after player has connected
    %offline,                      # commands for before player has connected
    %connected,                                # connected socket information
    %connected_user,                                        # users connected
    %honey,                                                   # honeypot cmds
    $readable,                                 # sockets to wait for input on
    $listener,                                                 # port details
    %code,                                   #  loaded perl files w/mod times
    $db,                                           # main database connection
    $log,                                      # database connection for logs
    %info,                                                # misc info storage
    $user,                                             # current user details
    $enactor,                                # object who initated the action
    $prog,                                      # currently running mush code
   );

#
# getfile
#    Load a file into memory and return the contents of that file
#
sub getfile
{
   my ($fn,$code) = @_;
   my($file, $out);

   if($fn =~ /^[^\\|\/]+\.(pl|dat)$/i) {
      open($file,$fn) || return undef;                         # open pl file
   } elsif($fn =~ /^[^\\|\/]+$/i) {
      open($file,"txt\/$fn") || return undef;                 # open txt file
   } else {
      return undef;                                 # don't open file because
   }                                          # it doesn't follow conventions

   @{$$code{$fn}}{lines} = 0 if(ref($code) eq "HASH");
   while(<$file>) {                                           # read all data
      @{$$code{$fn}}{lines}++ if(ref($code) eq "HASH");
      $out .= $_;
   }
   close($file); 
   $out =~ s/\r//g;
   $out =~ s/\n/\r\n/g;

   return $out;                                                 # return data
}

#
# load_code_in_file
#    Load perl code from a file and run it.
#
sub load_code_in_file
{
   my ($file,$verbose) = @_;

   if(!-e $file) {
      printf("Fatal: Could not find '%s' to load.\n",$file);
   } else {
      my $data = getfile($file,\%code);                      # read code in

      @{@code{$file}}{size} = length($data);
      if($verbose) {                                  # show whats happening
         printf("Loading: %s [%s bytes]\n",$file,@{@code{$file}}{size});
      }

      eval($data);                                                # run code
      if($@) {                                         # report any failures
         printf("\nload_code fatal: '%s'\n",$@);
         return 0;
      }
   }
   return 1;                                           # everything was good
}

#
# load_all_code
#    Check the current directory for any perl files to load. See if the
#    file has changed and reload it if it has. Exclude tm_main.pl
#    which should never be reloaded.
#
sub load_all_code
{
   my $verbose = shift;
   my ($dir, @file);

   opendir($dir,".") ||
      return "Could not open current directory for reading";

   for my $file (readdir($dir))  {
      if($file =~ /^tm_.*.pl$/i && $file !~ /(backup|test)/ && 
         $file !~ /^tm_(main).pl$/i) {
         my $current = (stat($file))[9];         # should be file be reloaded?
         if(!defined @code{$file} || @{@code{$file}}{mod} != $current) {
            @code{$file} = {} if not defined @code{$file};
            if(load_code_in_file($file,1)) {
               push(@file,$file);                  # show which files reloaded
               @{@code{$file}}{mod} = $current;
            } else {
               push(@file,"$file [err]");                  # show which failed
            }
         }
      }
   }
   closedir($dir);
   return join(', ',@file);                           # return succ/fail list
}

@info{version} = "TeenyMUSH 0.5";

printf("Loading: tm_mysql.pl\n");
load_code_in_file("tm_mysql.pl");                       # only call of main
load_all_code(1);                                # initial load of code
printf("Loading: tm_main.pl\n");
load_code_in_file("tm_main.pl");                       # only call of main

printf("### DONE ###\n");            # should never get here unless @shutdown