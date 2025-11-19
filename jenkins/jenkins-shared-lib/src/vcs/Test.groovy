#!/usr/bin/groovy
package vcs

def name 
def init(String name){
    this.name = name
}
def testfunction(String name){
    echo "${name}"
}
// class Test {
//     String name

//     Test(String name){
//         this.name = name
//     }

//     def testfunction(String name){
//         echo "${name}"
//     }
// }