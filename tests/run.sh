echo "---------Building native dylib---------"
cd ./native
echo $(swift build)

# echo "----------Compiling typescript---------"
cd ../
# echo $(npx tsc --build)

# echo "----------Executing jest tests---------"
# yarn exec jest --debug

# echo "---run without jest for swift output---"
ts-node tests/nonJestTests.ts





