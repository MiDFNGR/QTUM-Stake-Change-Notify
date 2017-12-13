#!/bin/bash
#
# Configuration Variables
#
SENDER=youraddress@gmail.com
NOTIFYRECIPIENT=5558671234@tmomail.net
INFORECIPIENT=youraddress@gmail.com
HOMEDIR=/home/qtum
#
# Static Variables
#
SUBJECT="QTUM Stake Change"
QTUMCLI=$HOMEDIR/qtum-wallet/bin/qtum-cli
SCRIPTDIR=qt-notify
SCRIPTNAME=$(basename -- "$0")
PIDDIR=$HOMEDIR/$SCRIPTDIR/run
LOGDIR=$HOMEDIR/$SCRIPTDIR/logs
WORKDIR=$HOMEDIR/$SCRIPTDIR/work
PREVIOUSSTAKEFILE=$WORKDIR/stake.previous.value
CURRENTSTAKEFILE=$WORKDIR/stake.current.value
PREVIOUSINFOFILE=$WORKDIR/getinfo.previous
CURRENTINFOFILE=$WORKDIR/getinfo.current
#
######################
# Code Execution Below
#
if ! test -d $PIDDIR
then
    mkdir $PIDDIR
fi
if ! test -s $PIDDIR/$SCRIPTNAME.pid
then
    echo 69696969 > $PIDDIR/$SCRIPTNAME.pid
fi
if ! test -d $LOGDIR
then
    mkdir $LOGDIR
fi
if ! test -d $WORKDIR
then
    mkdir $WORKDIR
fi
#
###################################################
# Check to see if I am already running, if so, exit
#
CHECKPID=$(<$PIDDIR/$SCRIPTNAME.pid)
if ps -ef |grep -w $CHECKPID |grep $SCRIPTNAME > /dev/null
then
    exit 1
else
    ########################
    # Main Program Execution
    #
    # First, write current Process ID to .pid file
    #
    echo $$ > $PIDDIR/$SCRIPTNAME.pid
    #
    # If previous stake file does not exist, switch to TEST NOTIFICATION
    #
    if ! test -s $PREVIOUSSTAKEFILE
    then
        SUBJECT="QTUM Notify Test"
        echo "Test" > $PREVIOUSSTAKEFILE
        echo "Test_Email" > $PREVIOUSINFOFILE
    fi
    #
    # Get info from QTUM wallet
    #
    $QTUMCLI getinfo > $CURRENTINFOFILE
    #
    # Check if wallet is unlocked - if not, send notifications
    #
    UNLOCKED=`grep "unlocked_until" $CURRENTINFOFILE |cut -d ':' -f2 |sed 's/ //g' |sed 's/,//g'`
    #
    if [ $UNLOCKED -eq 0 ]
    then
        # If we have already sent wallet-locked notifications, exit
        #
        if test -s $WORKDIR/locked_notify
        then
            exit
        else
            # Email wallet locked notifications
            #
            SUBJECT="QTUM Wallet is Locked"
            echo -e "FROM: $SENDER\nTO: $NOTIFYRECIPIENT\nSubject: $SUBJECT\n\n\n\nQTUM Wallet is Locked.\n\nPlease log in and unlock it." | /usr/sbin/sendmail -t
            echo -e "FROM: $SENDER\nTO: $INFORECIPIENT\nSubject: $SUBJECT\n\nQTUM Wallet is Locked.\n\nPlease log in and unlock it." | /usr/sbin/sendmail -t
            #
            # Create locked_notify flag
            #
            echo 1 > $WORKDIR/locked_notify
            exit
        fi
    else
        # if locked_notify flag exists, delete it
        #
        if test -s $WORKDIR/locked_notify
        then
            rm $WORKDIR/locked_notify
        fi
    fi
    #
    # Get bare stake values
    #
    cat $CURRENTINFOFILE |grep "\"stake\"\:" |cut -d ':' -f2 |sed 's/ //g' |sed 's/,//g' > $CURRENTSTAKEFILE
    #
    CURRENTSTAKE=$(<$CURRENTSTAKEFILE)
    PREVIOUSSTAKE=$(<$PREVIOUSSTAKEFILE)
    #
    if [ "$CURRENTSTAKE" != "$PREVIOUSSTAKE" ]
    then
        #
        # Detected a stake change - Wait for 6 confirmations (blocks)
        #
        BLOCK=`grep "blocks" $CURRENTINFOFILE |cut -d ':' -f2 |sed 's/ //g' |sed 's/,//g'`
        CURRENTBLOCK=$BLOCK
        TARGETBLOCK=$(( $CURRENTBLOCK + 6 ))
        #
        # If SUBJECT="QTUM Notify Test", then skipt the wait
        #
        if [ "$SUBJECT" == "QTUM Notify Test" ]
        then
            TARGETBLOCK=$CURRENTBLOCK
        fi
        #
        until [ $CURRENTBLOCK -ge $TARGETBLOCK ]; do
            #
            sleep 10
            LATESTSTAKE=`$QTUMCLI getinfo |grep "\"stake\"\:" |cut -d ':' -f2 |sed 's/ //g' |sed 's/,//g'`
            #
            # If latest stake value equals previous stake value,
            # then log orphaned stake and exit
            #
            if [ $LATESTSTAKE == $PREVIOUSSTAKE ]
            then
                DATE=`date`
                echo "$DATE,Block=$BLOCK" >> $LOGDIR/stake_orphans.log
                exit
            fi
            #
            CURRENTBLOCK=`$QTUMCLI getinfo |grep "blocks" |cut -d ':' -f2 |sed 's/ //g' |sed 's/,//g'`
        done
        #
        # 6 confirmations have completed - stake change is valid
        #
        # If SUBJECT is not "QTUM Notify Test", log the stake change
        #
        if [ "$SUBJECT" != "QTUM Notify Test" ]
        then
            DATE=`date`
            echo "$DATE,Block=$BLOCK,$PREVIOUSSTAKE,$CURRENTSTAKE" >> $LOGDIR/stake_changes.log
        fi
        #
        # Email stake change notifications
        #
        CURRENTINFO=$(<$CURRENTINFOFILE)
        PREVIOUSINFO=$(<$PREVIOUSINFOFILE)
        #
        echo -e "FROM: $SENDER\nTO: $NOTIFYRECIPIENT\nSubject: $SUBJECT\n\n\n\nCurrent stake: $CURRENTSTAKE\n\nPrevious stake: $PREVIOUSSTAKE\n\nCheck email for more information..." | /usr/sbin/sendmail -t
        echo -e "FROM: $SENDER\nTO: $INFORECIPIENT\nSubject: $SUBJECT\n\nQTUM Stake Change...\n\nCurrent getinfo:\n\n$CURRENTINFO\n\nPrevious getinfo:\n\n$PREVIOUSINFO" | /usr/sbin/sendmail -t
        #
        mv $CURRENTSTAKEFILE $PREVIOUSSTAKEFILE
        mv $CURRENTINFOFILE $PREVIOUSINFOFILE
    else
        rm $CURRENTINFOFILE
        rm $CURRENTSTAKEFILE
    fi
    #
    exit
fi
