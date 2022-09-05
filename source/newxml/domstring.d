module newxml.domstring;

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
    this() @nogc nothrow pure {

    }
    this(const(DOMString) other) nothrow pure {
        buffer = other.buffer.dup;
        backPos = buffer.length;
    }
    this(XMLCh* other) @nogc @trusted nothrow pure {
        buffer = fromStringz(other);
        backPos = buffer.length;
    }
    this(XMLCh* other, size_t length) @nogc @system nothrow pure {
        buffer = other[0..length];
        backPos = buffer.length;
    }
    version (newxml_force_utf8) {

    } else {
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
    void appendData(XMLCh* other) @trusted nothrow pure {
        buffer ~= fromStringz(other);
        backPos = buffer.length;
    }
    void appendData(XMLCh ch) nothrow pure {
        buffer ~= ch;
        backPos = buffer.length;
    }
    void appendData(DOMString other) nothrow pure {
        buffer ~= other.buffer;
        backPos = buffer.length;
    }
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
    XMLCh charAt(size_t index) @nogc nothrow pure {
        return buffer[index];
    }
    DOMString clone() nothrow pure const {
        return new DOMString(this);
    }
    //TO DO:read up on how this works
    int compareString(DOMString other) {
        return int.init;
    }
    void deleteData(size_t offset, size_t count) pure {
        if (offset + count > buffer.length) 
            throw new XMLException("offset + count larger than buffer length!");
        buffer = buffer[0..offset] ~ buffer[offset+count..$];
        backPos = buffer.length;
    }
    bool equals(XMLCh* other) @trusted pure const {
        auto str = fromStringz(other);
        if (str.length != buffer.length) return false;
        return fastEqual(buffer, str);
    }
    bool equals(DOMString other) pure const {
        if (buffer.length != other.length) return false;
        return fastEqual(buffer, other.buffer);
    }
    bool equals(T)(T other) pure const {
        if (buffer.length != other.length) return false;
        return fastEqual(buffer, other);
    }
    void insertData(size_t offset, DOMString data) pure nothrow {
        buffer = buffer[0..offset] ~ data.buffer ~ buffer[offset..$];
    }
    void insertData(size_t offset, XMLCh[] other) pure nothrow {
        buffer = buffer[0..offset] ~ other ~ buffer[offset..$];
    }
    bool opEquals(R)(R other) pure const {
        return equals(other);
    }
    auto opOpAssign(string op, R)(R rhs) {
        static if(op == "+" || op == "~"){
            appendData(rhs);
        }
    }
    void print() const {
        import std.stdio;
        write(buffer);
    }
    void println() const {
        import std.stdio;
        writeln(buffer);
    }
    XMLCh* rawBuffer() @system @nogc nothrow pure const {
        return buffer.ptr;
    }
    alias ptr = rawBuffer;
    XMLCh[] getDString() @nogc nothrow pure const {
        return buffer;
    }
    void reserve(size_t size) nothrow pure {
        buffer.reserve(size);
    }
    DOMString substringData(size_t offset, size_t count) nothrow pure const {
        return new DOMString(buffer[offset..offset + count]);
    }
    immutable(char)* transcode() @trusted pure nothrow const {
        return toStringz(toUTF8(buffer));
    }
    string transcodeToUTF8() pure nothrow const {
        return toUTF8(buffer);
    }
    wstring transcodeToUTF16() pure nothrow const {
        return toUTF16(buffer);
    }
    dstring transcodeToUTF32() pure nothrow const {
        return toUTF32(buffer);
    }
    //range stuff begins here
    ///
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

    ///
    void popFront() {
        if (frontPos + 1 < backPos)
            frontPos++;
    }

    ///
    @property bool empty() {
        return !(frontPos + 1 < backPos);
    }

    /* Measurements of the benefits of using opApply instead of range primitives
     * for foreach, using timings for iterating over an iota(100_000_000) range
     * with an empty loop body, using the same hardware in each case:
     *
     * Bare Iota struct, range primitives:  278 milliseconds
     * InputRangeObject, opApply:           436 milliseconds  (1.57x penalty)
     * InputRangeObject, range primitives:  877 milliseconds  (3.15x penalty)
     */

    ///
    /* @property ForwardRange!XMLCh save() {
        return this;
    }
    ///
    @property BidirectionalRange!XMLCh save() {
        return this;
    } */

    ///
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

    ///
    void popBack() {
        if (backPos > 1)
            backPos--;
    }
    ///
    @property RandomAccessFinite!XMLCh save() {
        return new DOMString(this);
    }

    ///
    XMLCh opIndex(size_t index) @nogc nothrow pure const {
        return buffer[index];
    }
    DOMString opSlice(size_t from, size_t to) nothrow pure const {
        return new DOMString(buffer[from..to]);
    }
    ///
    XMLCh moveAt(size_t pos) @nogc nothrow pure {
        frontPos = pos;
        return buffer[frontPos];
    }

    ///
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