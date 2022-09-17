# Current

* `newxml.domimpl.DOMImplementation.Element.Map.opSlice` restored.
* Added function `newxml.parseXMLString()` for easy XML parsing.
* Code readability improvements.
* Basic Doctype handling added to the SAX parser.
* Basic Doctype handling added to the DOM, with internal entity handling.

### Known issues

* Namespace URIs are not handled currently.

# v0.2.1

* Removal of `newxml.domimpl.DOMImplementation.Element.Map.opSlice`, since it caused issues with LDC2, and it's not part of the DOM standard.

# v0.2.0

Initial version.