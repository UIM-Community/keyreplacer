# keyreplacer
CA UIM Probe configuration replacer

# Warning

This script only work with the controller (robot). 

```perl
my $RC = $robot->getRobotCFG("$Output_directory/$Execution_Date");
if($RC == NIME_OK) {
    if($robot->scanRobotCFG("$Output_directory/$Execution_Date","$KR_key","$KR_value")) {
        $Console->print("[n' $count] Add $robot->{name}");
        push(@PoolOfRobots_toReconfigure,$robot);
    }
}
```

Feel free to pull-request a evolution of this. The idea is to get the cfg of the focused probe (the version of perluim framework does'nt have a method like that on robot, only on probe).
