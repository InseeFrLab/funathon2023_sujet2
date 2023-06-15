#! /bin/bash

PROJECT_DIR=~/work/funathon2023_sujet2
git clone https://github.com/InseeFrLab/funathon2023_sujet2.git $PROJECT_DIR
chown -R onyxia:users $PROJECT_DIR/
cd $PROJECT_DIR

git config --global credential.helper store

# s3 data
mc cp s3/projet-funathon/2023/sujet2/diffusion/era5.zip ~/work/funathon2023_sujet2/data/era5.zip
unzip ~/work/funathon2023_sujet2/data/era5.zip -d ~/work/funathon2023_sujet2/data/
rm ~/work/funathon2023_sujet2/data/era5.zip

# install
sudo apt-get update
sudo apt-get install -y protobuf-compiler libprotobuf-dev libprotoc-dev
