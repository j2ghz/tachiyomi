#!/bin/bash
set -e

git fetch --unshallow #required for commit count

cp .travis/google-services.json app/

if [ -z "$TRAVIS_TAG" ]; then
    ./gradlew clean assembleStandardDebug

    COMMIT_COUNT=$(git rev-list --count HEAD)
    export ARTIFACT="tachiyomi-r${COMMIT_COUNT}.apk"

    mv app/build/outputs/apk/standard/debug/app-standard-debug.apk $ARTIFACT
else
    ./gradlew clean assembleStandardRelease

    TOOLS="$(ls -d ${ANDROID_HOME}/build-tools/* | tail -1)"
    export ARTIFACT="tachiyomi-${TRAVIS_TAG}.apk"

    ${TOOLS}/zipalign -v -p 4 app/build/outputs/apk/standard/release/app-standard-release-unsigned.apk app-aligned.apk
    ${TOOLS}/apksigner sign --ks $STORE_PATH --ks-key-alias $STORE_ALIAS --ks-pass env:STORE_PASS --key-pass env:KEY_PASS --out $ARTIFACT app-aligned.apk
fi

user=j2ghz
git clone --recurse-submodules https://${user}:${PAT}@github.com/${user}/fdroid-data.git
cd fdroid-data
cp ../${ARTIFACT} ./repo/
docker run --rm -u $(id -u):$(id -g) -v $(pwd):/repo registry.gitlab.com/fdroid/docker-executable-fdroidserver:latest update -v
cd repo
git config --global user.name "Travis CI"
git config --global user.email "travis@travis-ci.com"
git add . -v
git commit -m "Update: ${TRAVIS_REPO_SLUG}@${TRAVIS_COMMIT}"
git push https://${user}:${PAT}@github.com/${user}/repo.git HEAD:master --force
cd ..
git add . -v
git commit -m "Update: ${TRAVIS_REPO_SLUG}@${TRAVIS_COMMIT}"
git push https://${user}:${PAT}@github.com/${user}/fdroid-data.git HEAD:master --force
