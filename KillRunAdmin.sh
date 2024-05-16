pid=`ps -ef | grep -v grep |grep 'DU_ADMIN-0.0.1' | sed -n  '1P' | awk '{print $2}'`
if [ -z $pid ] ; then
    echo "First Run"  
else
    echo Kill $pid and Restart 
    kill $pid
fi

cd admin
java -jar DU_ADMIN-0.0.1.jar --spring.profiles.active=aws &

