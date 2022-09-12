module newxml.domstring;

import std.algorithm.comparison : equal;
import std.exception : enforce;
import std.range;
import std.string;
import std.utf;

import newxml.faststrings;
import newxml.interfaces;

version (newxml_force_utf8) {
    alias XMLCh = immutable(char);
} else version (newxml_force_utf32) {
    alias XMLCh = immutable(dchar);
} else {
    alias XMLCh = immutable(wchar);
}
/** 
 * Proper DOMString implementation, with some added range capabilities.
 * Authors: 
 *  László Szerémi
 * Contains UTF-16 strings by default, but can be configured to either UTF-8 or UTF-32 with version labels.
 */
public class DOMString : RandomAccessFinite!XMLCh {
    ///Stores the character data.
    private XMLCh[] buffer;
    ///Front and rear positions.
    private size_t frontPos, backPos;
    /**`foreach` iteration uses opApply, since one delegate call per loop
     * iteration is faster than three virtual function calls.
     * TO DO: Use metaprogramming to make it able to be used in all sorts of context.
     */
    int opApply(scope int delegate(XMLCh) deleg) {
        for (size_t i ; i < buffer.length ; i++) {
            int result = deleg(buffer[i]);
            if (result) return result;
        }
        return 0;
    }

    /// Ditto
    int opApply(scope int delegate(size_t, XMLCh) deleg) {
        for (size_t i ; i < buffer.length ; i++) {
            int result = deleg(i, buffer[i]);
            if (result) return result;
        }
        return 0;
    }
@safe:
    /** 
     * Default constructor for DOMString. The resulting DOMString object refers to no string at all
     * Difference from C++ implementation: Does not compare with 0
     */
    this() @nogc nothrow pure {

    }
    ///Copy constructor.
    this(const(DOMString) other) nothrow pure {
        buffer = other.buffer.dup;
        backPos = buffer.length;
    }
    ///Constructor to build a DOMString from an XML character array. (XMLCh is a UTF-16 character by default, can be configured with version labels)
    this(XMLCh* other) @nogc @trusted nothrow pure {
        buffer = fromStringz(other);
        backPos = buffer.length;
    }
    /** 
     * Constructor to build a DOMString from a character array of given length.
     * Params:
     *   other = The character array to be imported into the DOMString
     *   length = The length of the character array to be imported
     */
    this(XMLCh* other, size_t length) @nogc @system nothrow pure {
        buffer = other[0..length];
        backPos = buffer.length;
    }
    version (newxml_force_utf8) {

    } else {
        /** 
         * Constructor to build a DOMString from an 8 bit character array.
         * Params:
         *   other = The character array to be imported into the DOMString
         */
        this(const(char)* other) @trusted nothrow pure {
            version (newxml_force_utf32) {
                buffer = toUTF32(fromStringz(other));
            } else {
                buffer = toUTF16(fromStringz(other));
            }
            backPos = buffer.length;
        }
    }
    ///Creates DOMString objects from standard D strings.
    this(T)(T[] other) nothrow pure {
        version (newxml_force_utf8) {
            buffer = toUTF8(other);
        } else version (newxml_force_utf32) {
            buffer = toUTF32(other);
        } else {
            buffer = toUTF16(other);
        }
        backPos = buffer.length;
    }
    /** 
     * Append a null-terminated XMLCh * (Unicode) string to this string.
     * Params:
     *   other = The object to be appended
     */
    void appendData(XMLCh* other) @trusted nothrow pure {
        buffer ~= fromStringz(other);
        backPos = buffer.length;
    }
    /** 
     * Append a single Unicode character to this string.
     * Params:
     *   ch = The single character to be appended
     */
    void appendData(XMLCh ch) nothrow pure {
        buffer ~= ch;
        backPos = buffer.length;
    }
    /** 
     * Appends the content of another DOMString to this string.
     * Params:
     *   other = The object to be appended
     */
    void appendData(DOMString other) nothrow pure {
        buffer ~= other.buffer;
        backPos = buffer.length;
    }
    /** 
     * Appends a D string to this string.
     * Params:
     *   other = The D string (string/wstring/dstring) as an array
     */
    void appendData(T)(T[] other) nothrow pure {
        version (newxml_force_utf8) {
            buffer ~= toUTF8(other);
        } else version (newxml_force_utf32) {
            buffer ~= toUTF32(other);
        } else {
            buffer ~= toUTF16(other);
        }
        backPos = buffer.length;
    }
    /** 
     * Returns the character at the specified position.
     * Params:
     *   index = The position at which the character is being requested
     * Returns: Returns the character at the specified position.
     */
    XMLCh charAt(size_t index) @nogc nothrow pure {
        return buffer[index];
    }
    /** 
     * Makes a clone of a the DOMString.
     * Returns: The object to be cloned.
     */
    DOMString clone() nothrow pure const {
        return new DOMString(this);
    }
    //TO DO:read up on how this works
    int compareString(DOMString other) {
        return int.init;
    }
    /** 
     * Clears the data of this DOMString.
     * Params:
     *   offset = The position from the beginning from which the data must be deleted 
     *   count = The count of characters from the offset that must be deleted 
     */
    void deleteData(size_t offset, size_t count) pure {
		enforce!XMLException(offset + count <= buffer.length
            , "offset + count larger than buffer length!");
        buffer = buffer[0..offset] ~ buffer[offset+count..$];
        backPos = buffer.length;
    }
    /** 
     * Compare a DOMString with a null-terminated raw 16-bit character string. 
     * Params:
     *   other = The character string to be compared with. 
     * Returns: True if the strings are the same, false otherwise. 
     */
    bool equals(XMLCh* other) @trusted pure const {
        auto str = fromStringz(other);
        if (str.length != buffer.length) return false;
        return equal(buffer, str);
    }
    /** 
     * Tells if a DOMString contains the same character data as another.
     * Params:
     *   other = The DOMString to be compared with.
     * Returns: True if the two DOMStrings are same, false otherwise.
     */
    bool equals(DOMString other) pure const {
        if (buffer.length != other.length) return false;
        return equal(buffer, other.buffer);
    }
    /** 
     * Compares the content of a D string against a DOMString.
     * Params:
     *   other = The D string to be compared with.
     * Returns: True if their textual data are the same, false otherwise.
     */
    bool equals(T)(T other) pure const {
        XMLCh[] o;
        version (newxml_force_utf8)
            o = toUTF8(other);
        else version (newxml_force_utf32)
            o = toUTF32(other);
        else
            o = toUTF16(other);
        if (buffer.length != o.length) return false;
        return equal(buffer, o);
    }
    /** 
     * Inserts a string within the existing DOMString at an arbitrary position.
     * Params:
     *   offset = The offset from the beginning at which the insertion needs to be done in this object 
     *   data = The DOMString containing the data that needs to be inserted
     */
    void insertData(size_t offset, DOMString data) pure nothrow {
        buffer = buffer[0..offset] ~ data.buffer ~ buffer[offset..$];
    }
    /** 
     * Inserts a string of type XMLCh within the existing DOMString at an arbitrary position
     * Params:
     *   offset = The offset from the beginning at which the insertion needs to be done in this object 
     *   other = The DOMString containing the data that needs to be inserted
     */
    void insertData(size_t offset, XMLCh[] other) pure nothrow {
        buffer = buffer[0..offset] ~ other ~ buffer[offset..$];
    }
    /** 
     * Compares the string against various other types or itself using the `==` and `!=` operators.
     * Params:
     *   other = The instance of the type to be tested against.
     * Returns: True if they have the same textual data, false otherwise.
     */
    bool opEquals(R)(R other) pure const {
        return equals(other);
    }
    T opCast(T)() const {
        static if (is(T == string)) {
            return transcodeToUTF8;
        } else static if (is(T == wstring)) {
            return transcodeToUTF16;
        } else static if (is(T == dstring)) {
            return transcodeToUTF32;
        }
    }
    /** 
     * Implements easy array appending with operator overloading.
     * Params:
     *   rhs = The data to be appended to the string.
     */
    auto opOpAssign(string op, R)(R rhs) {
        static if(op == "+" || op == "~"){
            appendData(rhs);
        }
    }
    ///Dumps the DOMString on the console. 
    void print() const {
        import std.stdio;
        write(buffer);
    }
    ///Dumps the DOMString on the console with a line feed at the end.
    void println() const {
        import std.stdio;
        writeln(buffer);
    }
    ///Returns a handle to the raw buffer in the DOMString.
    XMLCh* rawBuffer() @system @nogc nothrow pure const {
        return buffer.ptr;
    }
    alias ptr = rawBuffer;
    ///Returns the underlying array (string).
    XMLCh[] getDString() @nogc nothrow pure const {
        return buffer;
    }
    /** 
     * Preallocate storage in the string to hold a given number of characters. A DOMString will grow its buffer on 
     * demand, as characters are added, but it can be more efficient to allocate once in advance, if the size is known.
     * Params:
     *   size = The number of characters to reserve.
     */
    void reserve(size_t size) nothrow pure {
        buffer.reserve(size);
    }
    /** 
     * Returns a sub-string of the DOMString starting at a specified position.
     * Params:
     *   offset = The offset from the beginning from which the sub-string is being requested.
     *   count = The count of characters in the requested sub-string
     * Returns: The sub-string of the DOMString being requested
     */
    DOMString substringData(size_t offset, size_t count) nothrow pure const {
        return new DOMString(buffer[offset..offset + count]);
    }
    /** 
     * Returns a copy of the string, transcoded to the local code page. The caller owns the (char *) string that is 
     * returned, and is responsible for deleting it.
     * Returns: A pointer to a newly allocated buffer of char elements, which represents the original string, but in 
     * the local encoding.
     * Note: This function is using the `toStringz` function, and rules of that apply here too.
     */
    immutable(char)* transcode() @trusted pure nothrow const {
        return toStringz(toUTF8(buffer));
    }
    /** 
     * Transcodes the string as a UTF-8 string
     * Returns: The content of this string as UTF-8 data.
     */
    string transcodeToUTF8() pure nothrow const {
        return toUTF8(buffer);
    }
    /** 
     * Transcodes the string as a UTF-16 string
     * Returns: The content of this string as UTF-16 data.
     */
    wstring transcodeToUTF16() pure nothrow const {
        return toUTF16(buffer);
    }
    /** 
     * Transcodes the string as a UTF-32 string
     * Returns: The content of this string as UTF-32 data.
     */
    dstring transcodeToUTF32() pure nothrow const {
        return toUTF32(buffer);
    }
    ///Templated transcoder.
    T transcodeTo(T)() pure nothrow const {
        static if (is(T == string))
            return transcodeToUTF8;
        else static if (is(T == wstring))
            return transcodeToUTF16;
        else static if (is(T == dstring))
            return transcodeToUTF32;
        else static assert(0, "Template parameter `" ~ "` not supported for function `DOMString.transcodeTo(T)()`");
    }
    //range stuff begins here
    ///Returns the front element of the range.
    @property XMLCh front() @nogc nothrow pure {
        return buffer[frontPos];
        
    }
    /**Calls $(REF moveFront, std, range, primitives) on the wrapped range, if
     * possible. Otherwise, throws an $(LREF UnsupportedRangeMethod) exception.
     */
    XMLCh moveFront() {
        if (frontPos + 1 < backPos)
            frontPos++;
        return buffer[frontPos];
    }

    ///Moves the front pointer up by one.
    void popFront() {
        if (frontPos + 1 < backPos)
            frontPos++;
    }

    ///Returns true if all content of the string have been consumed.
    @property bool empty() {
        return !(frontPos + 1 < backPos);
    }
    ///Returns the back element of the range.
    @property XMLCh back() {
        return buffer[backPos - 1];
    }

    /**Calls $(REF moveBack, std, range, primitives) on the wrapped range, if
     * possible. Otherwise, throws an $(LREF UnsupportedRangeMethod) exception
     */
    XMLCh moveBack() {
        if (backPos > 1)
            backPos--;
        return buffer[backPos];
    }
    ///Moves the back pointer down by one.
    void popBack() {
        if (backPos > 1)
            backPos--;
    }
    ///Returns a copy of the DOMString.
    @property RandomAccessFinite!XMLCh save() {
        return new DOMString(this);
    }
    ///Allows the characters to be accessed in an array-like fashion.
    XMLCh opIndex(size_t index) @nogc nothrow pure const {
        return buffer[index];
    }
    /** 
     * Returns a slice of the string.
     * Params:
     *   from = The beginning point.
     *   to = The ending point + 1.
     * Returns: The content of the slice as a DOMString.
     */
    DOMString opSlice(size_t from, size_t to) nothrow pure const {
        return new DOMString(buffer[from..to]);
    }
    ///Moves the front pointer to the given position.
    XMLCh moveAt(size_t pos) @nogc nothrow pure {
        frontPos = pos;
        return buffer[frontPos];
    }
    ///Returns the length of the string.
    @property size_t length() @nogc nothrow pure const {
        return buffer.length;
    }

    ///
    alias opDollar = length;
}
unittest {
    DOMString test0 = new DOMString("Hello World!"), test1 = new DOMString("Hello World!"w), 
            test2 = new DOMString("Hello World!"d);
    assert(test0 == "Hello World!"w);
    assert(test1 == "Hello World!"w);
    assert(test2 == "Hello World!"w);
    assert(test1 == test2);
    assert(test0.length == 12);
    assert(test1.length == 12);
    assert(test2.length == 12);
    assert(test0[3..5].getDString == "lo");

    DOMString test3 = new DOMString("test");
    test3.insertData(2, "te");
    assert(test3 == "tetest");
    test3.deleteData(2, 2);
    assert(test3 == "test");
    foreach (size_t i, XMLCh c; test3) {
        assert(c == "test"[i]);
    }
}
