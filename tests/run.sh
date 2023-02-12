echo "---------Building native dylib---------"
cd ./native
echo $(swift build)

echo "----------Compiling typescript---------"
cd ../
echo $(npx tsc --build)

echo "----------Executing jest tests---------"
yarn exec jest





