# newxml
XML library for D with DOM compatibility. Based on the never finished experimental.xml library.

DOM (https://dom.spec.whatwg.org/) is a widely used cross-platform standard for implementing XML libraries, and has 
been used for languages like C++, Java, Javascript, Python, etc. in some form or another.

## Differences from regular DOM

* Some templates have been added to make things easier.
* Configurable default StringType.

## Differences between newxml and experimental.xml

* newxml has an active development.
* newxml is GC only, for simplicity sake.
* newxml implements proper DOMString, with the option of configuring it to either UTF-8 or UTF-32 instead of the 
UTF-16, which is default in DOM.
* newXML has memory safety implemented.
