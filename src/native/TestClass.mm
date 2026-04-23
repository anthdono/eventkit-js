#include <random>

class TestClass {

public:
    TestClass(){
        std::random_device rd; 
        std::mt19937 gen(rd()); 
        std::uniform_int_distribution<int> dist(1, 100); 
        this->value = dist(gen);
    }

    uint32_t value;

};
