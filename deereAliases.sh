#John Deere Stuff
alias dataloader="C:/bench/HDP/HDP/bin/x64/Debug/JohnDeere.HDP.DataLoader.exe -new_console"
alias getkeys="python /c/bench/ads-infrastructure/credentials/get_temp_keys.py"
alias rv="rake verify"
alias mci="mvn clean install"
alias tree="mvn dependency:tree > deps.txt"
alias avro="java -jar /c/bench/tools/avro/avro-tools-1.8.2.jar"
alias kspy="C:/bench/KinesisSpy/bin/Debug/KinesisSpy.exe &"
alias kmsdecrypt="'kmsDecryption'"
alias jq="c:/bench/tools/jq/jq.exe"
alias qretry="'moveManyErrorQueuesBackToMain'"
alias qclear="'clearOutErrorQueues'"
alias qprint="'printOutErrorQueues'"

function kmsDecryption() {
    kmsFile="kms_encrypted_binary.tmp"
    winTempDir=`cygpath -d $TEMP`
    base64 --decode $1 > $TEMP/$kmsFile
    aws kms decrypt --region us-east-1 --ciphertext-blob fileb://$winTempDir/$kmsFile --output text --query Plaintext | base64 --decode --ignore-garbage
    rm $TEMP/$kmsFile
}

function printOutErrorQueues(){
    curDir=$PWD
    cd /c/bench
    env=$2
    queueName=$(getHdpStreamName $3 $1)
    echo "$queueName.ERROR:"

    primaryQ="./queue-utility/printq.bat $env primary $queueName.ERROR"
    prettyPrintQueue "Primary" $env $queueName "$primaryQ"

    backupQ="./queue-utility/printq.bat $env backup $queueName.ERROR"
    prettyPrintQueue "Backup" $env $queueName "$backupQ"

    cd $curDir
}

function prettyPrintQueue(){
    tempFile="$tmp/qprettytempfile.txt"

    echo "$1"
    eval "$4 > $tempFile"

    searchString="><"
    replaceString=">\n<"
    sed -i -e "s/$searchString/$replaceString/g" $tempFile
    searchString="<\/"
    replaceString=""
    sed -i "s/$searchString.*$/$replaceString/g" $tempFile
    searchString="<?"
    replaceString=""
    sed -i "s/$searchString.*$/$replaceString/g" $tempFile
    searchString="<"
    replaceString="__"
    sed -i -e "s/$searchString/$replaceString/g" $tempFile
    searchString=">"
    replaceString=": "
    sed -i -e "s/$searchString/$replaceString/g" $tempFile

    while read p; do
        if [[ $p == "_"* ]];
        then
            echo $p
        elif [[ $p != "P"* ]] && [[ $p != "" ]];
        then
            echo ""
            echo $p
        fi
    done < $tempFile

    rm -rf $tempFile
}

function clearOutErrorQueues(){
    curDir=$PWD
    cd /c/bench
    env=$2
    queueName=$(getHdpStreamName $3 $1)
    ./queue-utility/clearq.bat $env "$queueName.ERROR"
    cd $curDir
}

function moveManyErrorQueuesBackToMain(){
    iRegion=$1
    iEnv=$2
    iQueue=$3

    if [ $iRegion != "all" ]
    then
        if [ $iEnv != "all" ]
        then
            if [ $iQueue != "all" ]
            then
                moveErrorQueuesBackToMain $iRegion $iEnv $iQueue
            else
                loopQueueAndRetryErrors $iRegion $iEnv
            fi
        else
            loopEnvAndRetryErrors $iRegion
        fi
    else
        loopRegionAndRetryErrors
    fi
}

function loopQueueAndRetryErrors(){
    declare -a queueList=("FileProcess" "LogOperationUpdate" "GroupProcessing" "Aggregation" "MapGenerator" "PolygonGenerator" "ApexMigrator")

    for q in "${queueList[@]}"
    do
        moveErrorQueuesBackToMain $1 $2 $q
    done
}

function loopEnvAndRetryErrors(){
    declare -a envList=("prod" "cert" "qual" "devl")

    for e in "${envList[@]}"
    do
        loopQueueAndRetryErrors $1 $e
    done
}

function loopRegionAndRetryErrors(){
    declare -a regionList=("us" "eu")

    for r in "${regionList[@]}"
    do
        loopEnvAndRetryErrors $r
    done
}

function moveErrorQueuesBackToMain(){
    curDir=$PWD
    cd /c/bench
    env=$2
    queueName=$(getHdpStreamName $3 $1)

    primaryQ="./queue-utility/moveq.bat $env primary primary $queueName.ERROR $queueName"
    prettyPrintQueue "Primary" $env $queueName "$primaryQ"

    backupQ="./queue-utility/moveq.bat $env backup primary $queueName.ERROR $queueName"
    prettyPrintQueue "Primary" $env $queueName "$backupQ"

    cd $curDir
}

function getHdpStreamName(){
    region=${2,,}
    queueName=${1,,}
    actualName=""
    streamRegion=""

    if [ $region == "eu" ]
    then
        streamRegion=".R2"
    fi

    case "$queueName" in
        "fileprocess")
            actualName="ISG.AXIOM$streamRegion.HDPCOMM.PROCESSFILE.REQUEST"
            ;;
        "logoperationupdate")
            actualName="ISG.AXIOM$streamRegion.HDPCOMM.LOGOPERATION.REQUEST"
            ;;
        "groupprocessing")
            actualName="ISG.HDP$streamRegion.GROUPING.REQUEST"
            ;;
        "aggregation")
            actualName="ISG.HDP$streamRegion.AGGREGATION.REQUEST"
            ;;
        "mapgenerator")
            actualName="ISG.HDP$streamRegion.GENERATEMAPS.REQUEST"
            ;;
        "polygongenerator")
            actualName="ISG.HDP$streamRegion.GENERATEPOLYGONS.REQUEST"
            ;;
        "apexmigrator")
            actualName="ISG.AXIOM$streamRegion.HDPCOMM.PROCESSBACKUP.REQUEST"
            ;;
        *)
            ;;
    esac

    echo $actualName
}
