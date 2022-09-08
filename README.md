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

# Usage example

## DOM parser

Please read the official DOM manual (https://dom.spec.whatwg.org/) before using the library. It's pretty much the exact
same thing at this point, only a few functions might not work yet (see chapter "To do list"). It's also used for other
languages, so there's a good chance you already used it in C++, Python, Java, etc.

First, you should create the builder, then you can get the document built with it for further processing:

```d
import newxml;                                  //imports the whole library

string xml = [...];                             //the document to be processed.

auto builder =
         xml
        .lexer
        .parser
        .cursor
        .domBuilder(new domimpl.DOMImplementation());   //this creates the builder, in the future, I want to make a simpler solution for this problem.

builder.setSource(xml);                         //sets the source for the builder
builder.buildRecursive;                         //builds the document
Document doc = builder.getDocument;             //this function gets the document to be processed

assert(doc.firstChild.name == "xmlDoc")         //
[...]
```

## SAX parser

This is an event-driven parser, that calls various delegates when certain types of nodes are encountered, and passes 
the necessary data to them.

```d
import newxml;                                  //imports the whole library

string xml = [...];                             //the document to be processed.

auto parser =
         xml
        .lexer
        .parser
        .cursor
        .saxParser; //this creates the SAX parser, in the future, I want to make a simpler solution for this problem.

parser.setSource(xml);  //sets the source to be parsed

//This block sets up various event delegates.
parser.onDocument = &handler.onDocument;    
parser.onElementStart = &handler.onElementStart;
parser.onElementEnd = &handler.onElementEnd;
parser.onElementEmpty = &handler.onElementEmpty;
parser.onText = &handler.onText;
parser.onComment = &handler.onComment;
parser.onProcessingInstruction = &handler.onProcessingInstruction;

parser.processDocument();   //Processes the document, and calls the appropriate delegates for processing purposes.
```

## Low level parsers

Although very uncomfortable to use compared to its higher-level counterparts, the low-level API can sill be used for
parsing XML. e.g. you really need that extra memory and speed.

# To do list