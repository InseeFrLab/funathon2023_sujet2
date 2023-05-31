#! /bin/bash

PROJECT_DIR=~/work/funathon2023_sujet2
git clone https://github.com/InseeFrLab/funathon2023_sujet2.git $PROJECT_DIR
chown -R onyxia:users $PROJECT_DIR/
cd $PROJECT_DIR

git config --global credential.helper store
