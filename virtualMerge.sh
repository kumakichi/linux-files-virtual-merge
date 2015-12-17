#!/bin/bash

mapperFile="joined"
mapperFileFull="/dev/mapper/$mapperFile"
cleanerFile="cleaner$(date +%Y%m%d%H%M%S).sh"

loopSet="sudo losetup -v -f"
loopUnset="sudo losetup -d"
getSizeCmd="sudo blockdev --getsz"

mapCmd="sudo dmsetup create $mapperFile"
cleanMapCmd="sudo dmsetup remove $mapperFile"

declare -a files
declare -a sizes
declare -a loops

function calcAlreadySize()
{
    idx=$1
    size=0

    if [ $idx -ge 2 ]
    then
        for((i=1;i<$idx;i++))
        do
            let size+=${sizes[$i]}
        done
    fi

    echo $size
    return $size
}

filesNum=$#

if [ $filesNum -lt 1 ]
then
    echo "Usage: $0 [FILE]..."
    exit
fi

if [ -f $mapperFileFull ]
then
    echo "Already exists a file named $mapperFile"
    exit
fi

for((i=1;i<=$filesNum;i++))
do
    file=$(eval echo \$$i)

    # loop
    loopOut=$($loopSet $file)
    loopDev=$(echo $loopOut | awk '{print $4}')

    # statistic
    files[$i]=$file
    sizes[$i]=$($getSizeCmd $file)
    loops[$i]=$loopDev
done

# build createCmd

createCmd="echo -e \""
cleanCmd="$cleanMapCmd"

for((i=1;i<=$filesNum;i++))
do
    already=$(calcAlreadySize $i)
    createCmd=$createCmd"$already ${sizes[$i]} linear ${loops[$i]} 0\n"
    cleanCmd=$cleanCmd";$loopUnset ${loops[$i]}"
done
createCmd=$createCmd"\" | $mapCmd"

cat<<EOF>$cleanerFile
#!/bin/bash

$cleanCmd
rm -- "\$0"
EOF
chmod +x $cleanerFile

eval $createCmd

echo "created $mapperFileFull"
echo "remember to clean environment using $cleanerFile"
