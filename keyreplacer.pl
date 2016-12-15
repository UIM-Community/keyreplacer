# SCRIPT VERSION 1.0

# Require librairies!
use strict;
use warnings;
use Data::Dumper;
use DBI;

# Nimsoft
use lib "D:/apps/Nimsoft/perllib";
use lib "D:/apps/Nimsoft/Perl64/lib/Win32API";
use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;

# librairies
use perluim::main;
use perluim::log;
use perluim::file;
use perluim::utils;

# ************************************************* #
# Get servers list!
# ************************************************* #
my %IncludeRobots = ();
my $ActiveArg = 0;
if(scalar @ARGV > 0) {
    if($ARGV[0] eq "-f" && defined($ARGV[1])) {
        my ($rc,@rows) = new perluim::file($ARGV[1])->load();
        if($rc) {
            foreach(@rows) {
                $IncludeRobots{lc $_} = 1;
            }
        }
    }
}

# ************************************************* #
# Console & Global vars
# ************************************************* #
my $Console = new perluim::log("keyreplacer.log",6,0,"yes");
my $ScriptExecutionTime = time();
$Console->print("Execution start at ".localtime(),5);

my $CFG                 = Nimbus::CFG->new("keyreplacer.cfg");
my $Domain              = $CFG->{"setup"}->{"domain"} || undef;
my $Cache_delay         = $CFG->{"setup"}->{"output_cache_time"} || 432000;
my $Audit               = $CFG->{"setup"}->{"audit"} || 0;
my $Output_directory    = $CFG->{"setup"}->{"output_directory"} || "output";
my $Login               = $CFG->{"setup"}->{"nim_login"} || undef;
my $Password            = $CFG->{"setup"}->{"nim_password"} || undef;

my $KR_probe            = $CFG->{"replacer"}->{"probe"};
my $KR_key              = $CFG->{"replacer"}->{"key"};
my $KR_value            = $CFG->{"replacer"}->{"value"};
my $KR_section          = $CFG->{"replacer"}->{"section"};

sub breakApplication {
    $Console->print("Break Application (CTRL+C) !!!",0);
    $Console->close();
    exit(1);
}
$SIG{INT} = \&breakApplication;

# ************************************************* #
# Instanciating framework !
# ************************************************* #
$Console->print("Instanciating framework!",5);
my $SDK = new perluim::main($Domain);
$Console->print("Create $Output_directory directory.");
my $Execution_Date = perluim::utils::getDate();
$SDK->createDirectory("$Output_directory/$Execution_Date");
$Console->cleanDirectory("$Output_directory",$Cache_delay);

# nimLogin to the hub (if not a probe!).
nimLogin("$Login","$Password") if defined($Login) and defined($Password);

# CloseHandler sub
sub closeHandler {
    my $msg = shift;
    $Console->print($msg,0);
    $SDK->doSleep(2);
    $Console->copyTo("$Output_directory/$Execution_Date");
    $Console->close();
    exit(1);
}

my @PoolOfRobots_toReconfigure = ();

$Console->print('Get robots from infrastructure!');
my ($RC_Robot,%Robots) = $SDK->getAllRobots();

$Console->print('Processing robots list!');
my $count = 0;
my @FailedGetCFG = ();
foreach my $robot (values %Robots) {
    next if $ActiveArg and not exists $IncludeRobots{lc $robot->{name}};
    if($robot->{status} == 0) {
        $count++;
        my $RC = $robot->getRobotCFG("$Output_directory/$Execution_Date");
        if($RC == NIME_OK) {
            if($robot->scanRobotCFG("$Output_directory/$Execution_Date","$KR_key","$KR_value")) {
                $Console->print("[n' $count] Add $robot->{name}");
                push(@PoolOfRobots_toReconfigure,$robot);
            }
        }
        else {
            $Console->print("Failed to retrieve cfg for $robot->{name}",1);
            push(@FailedGetCFG,$robot->{name});
        }
    }
}

# Save serversList!
new perluim::file()->save('servers.txt',\@PoolOfRobots_toReconfigure,"name");
new perluim::file()->save('failed_get_cfg.txt',\@FailedGetCFG);

if(not $Audit) {
    my @FailedList = ();
    $Console->print('Rewrite hubname key for all defected robots!');
    foreach(@PoolOfRobots_toReconfigure) {
        my $RC = $_->probeConfig_set("$KR_probe","$KR_section","$KR_key","$KR_value");
        if($RC == NIME_OK) {
            my $RC_RS = $_->probe_restart("$KR_probe");
            $Console->print("[$RC] Update hubdomain key successfully for $_->{name} with RS => $RC_RS");
        }
        else {
            $Console->print("[$RC] Failed to update hubdomain key for $_->{name} with RC => $RC",1);
            push(@FailedList,$_->{name});
        }
    }
    new perluim::file()->save('failed_update.txt',\@FailedList);
}
else {
    $Console->print("End of the script... Audit mode is activated!");
}

$Console->print("Waiting 5 secondes before closing the script!",4);
$SDK->doSleep(5);

# ************************************************* #
# End of the script!
# ************************************************* #
$Console->finalTime($ScriptExecutionTime);
$Console->copyTo("$Output_directory/$Execution_Date");
$Console->close();
1;
