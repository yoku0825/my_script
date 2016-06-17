if docker stop gitbucket > /dev/null 2>&1 ; then
  docker rm gitbucket > /dev/null
fi

docker run -d -p 50088:8080 -p 52200:52200 -v ${PWD}/data:/gitbucket --name=gitbucket yoku0825/gitbucket
