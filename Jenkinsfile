node{
    stage("Download code from github repo"){
        git credentialsId: 'GIT_CREDENTIALS', url: 'https://github.com/Lyonga/nginx-test-app.git'
    }
    
    stage("Docker build"){
        sh 'docker version'
        sh 'docker build -t nginx-test-app .'
        sh 'docker image list'
        sh 'docker tag nginx-test-app lyonga/project:nginx-test-app'
    }
    withCredentials([string(credentialsId: 'PASSWORD', variable: 'DOCKER_HUB_PASSWORD')]) {
     sh 'docker login -u lyonga -p $PASSWORD'
   }

    stage("Push Image to Docker Hub"){
        sh 'docker push  lyonga/project:nginx-test-app'
    }
    
    stage("Deploy spring boot to k8s cluster"){
        sh 'kubectl apply -f devops/nginx-test.yaml'
    }
}
