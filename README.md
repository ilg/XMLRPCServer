# XMLRPCServer

[![Build & Test][buildtest-image]][buildtest-url]
[![Swift Version][swift-image]][swift-url]
[![License][license-image]][license-url]
[![codebeat-badge][codebeat-image]][codebeat-url]

Swift XML-RPC server built with [Ambassador](https://github.com/envoy/Ambassador). 

Uses [XMLRPCCoder](/ilg/XMLRPCCoder/).  Counterpart to [XMLRPCClient](/ilg/XMLRPCClient/).

## Installation

Add this project on your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(
            url: "https://github.com/ilg/XMLRPCServer.git", 
            branch: "main"
        )
    ]
)
```

## Usage example


```swift
import XMLRPCServer

// TODO: write example code
```


## Development setup

Open [Package.swift](Package.swift), which should open the whole package in Xcode.  Tests can be run in Xcode.

Alternately, `swift test` to run the tests at the command line.

Use `bin/format` to auto-format all the Swift code.

[buildtest-image]:https://github.com/ilg/XMLRPCServer/actions/workflows/build-and-test.yml/badge.svg
[buildtest-url]:https://github.com/ilg/XMLRPCServer/actions/workflows/build-and-test.yml
[swift-image]:https://img.shields.io/badge/Swift-5.8-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
[codebeat-image]: https://codebeat.co/badges/9829260a-ce6f-4efd-9115-48ec4be1ea0b
[codebeat-url]: https://codebeat.co/projects/github-com-ilg-xmlrpcserver-main
