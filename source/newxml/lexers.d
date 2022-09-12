/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements various XML lexers.
+
+   The methods a lexer should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`);
+   The different lexers here implemented are optimized for different kinds of input
+   and different tradeoffs between speed and memory usage.
+
+   Authors:
+   Lodovico Giaretta
+   László Szerémi
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module newxml.lexers;

import newxml.interfaces;
import newxml.faststrings;

import std.exception : enforce;
import std.range.primitives;
import std.traits : isArray, isSomeFunction;
import std.string;

//import std.experimental.allocator;//import stdx.allocator;
//import std.experimental.allocator.gc_allocator;//import stdx.allocator.gc_allocator;

import std.typecons : Flag, Yes;

/**
 * Thrown on lexing errors.
 */
public class LexerException : Exception {
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
@safe:
/++
+   A lexer that takes a sliceable input.
+
+   This lexer will always return slices of the original input; thus, it does not
+   allocate memory and calls to `start` don't invalidate the outputs of previous
+   calls to `get`.
+
+   This is the fastest of all lexers, as it only performs very quick searches and
+   slicing operations. It has the downside of requiring the entire input to be loaded
+   in memory at the same time; as such, it is optimal for small file but not suitable
+   for very big ones.
+
+   Parameters:
+       T = a sliceable type used as input for this lexer
+/
struct SliceLexer(T)
{
    package T input;
    package size_t pos;
    package size_t begin;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    //mixin UsesAllocator!Alloc;
    //mixin UsesErrorHandler!ErrorHandler;

    /// ditto
    void setSource(T input)
    {
        this.input = input;
        pos = 0;
    }

    static if(isForwardRange!T)
    {
        auto save()
        {
            SliceLexer result = this;
            result.input = input.save;
            return result;
        }
    }

    /// ditto
    auto empty() const
    {
        return pos >= input.length;
    }

    /// ditto
    void start()
    {
        begin = pos;
    }

    /// ditto
    CharacterType[] get() const
    {
        return input[begin..pos];
    }

    /// ditto
    void dropWhile(string s)
    {
        while (pos < input.length && indexOf(s, input[pos]) != -1)
        {
            pos++;
        }
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        enforce!LexerException(!empty, "No more characters are found!");
            //handler();
        if (input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        enforce!LexerException(!empty, "No more characters are found!");
            //handler();
        auto adv = indexOf(input[pos..$], c);
        if (adv != -1)
        {
            pos += adv;
            enforce!LexerException(!empty, "No more characters are found!");
                //handler();
        }
        else
        {
            pos = input.length;
        }

        if (included)
        {
            enforce!LexerException(!empty, "No more characters are found!");
                //handler();
            pos++;
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        enforce!LexerException(!empty, "No more characters are found!");

        ptrdiff_t res;
        while ((res = indexOf(s, input[pos])) == -1)
        {
            enforce!LexerException(++pos < input.length
                    , "No more characters are found!");
        }

        if (included)
        {
            pos++;
        }

        return res;
    }
}

/++
+   A lexer that takes an InputRange.
+
+   This lexer copies the needed characters from the input range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is the most flexible lexer, as it imposes very few requirements on its input,
+   which only needs to be an InputRange. It is also the slowest lexer, as it copies
+   characters one by one, so it shall not be used unless it's the only option.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+/
struct RangeLexer(T)
    if (isInputRange!T)
{
    //import newxml.appender;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    //mixin UsesAllocator!Alloc;
    //mixin UsesErrorHandler!ErrorHandler;

    //private Appender!(CharacterType, Alloc) app;
    private CharacterType[] buffer;

    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        void setSource(T input)
        {
            this.input = input.representation;
            buffer.length = 0;
            //app = typeof(app)(allocator);
        }
    }
    else
    {
        private T input;
        void setSource(T input)
        {
            this.input = input;
            buffer.length = 0;
            //app = typeof(app)(allocator);
        }
    }

    static if (isForwardRange!T)
    {
        auto save()
        {
            RangeLexer result;
            result.input = input.save;
            result.buffer.length = 0;
            //result.app = typeof(app)(allocator);
            return result;
        }
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }

    /// ditto
    void start()
    {
        buffer.length = 0;
        /+static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);+/
    }

    /// ditto
    CharacterType[] get() const
    {
        return buffer;//app.data;
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && indexOf(s, input.front) != -1)
        {
            input.popFront();
        }
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        enforce!LexerException(!input.empty
            , "No more characters are found!");//handler();
        if (input.front == c)
        {
            buffer ~= input.front;//app.put(input.front);
            input.popFront();
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        enforce!LexerException(!input.empty
            , "No more characters are found!");//handler();
        while (input.front != c)
        {
            buffer ~= input.front;//app.put(input.front);
            input.popFront();
            enforce!LexerException(!input.empty
                , "No more characters are found!");//handler();
        }

        if (included)
        {
            buffer ~= input.front;//app.put(input.front);
            input.popFront();
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        enforce!LexerException(!input.empty
            , "No more characters are found!");//handler();
        size_t res;
        while ((res = indexOf(s, input.front)) == -1)
        {
            buffer ~= input.front;//app.put(input.front);
            input.popFront;
            enforce!LexerException(!input.empty
                , "No more characters are found!");//handler();
        }

        if (included)
        {
            buffer ~= input.front;// app.put(input.front);
            input.popFront;
        }
        return res;
    }
}

/++
+   A lexer that takes a ForwardRange.
+
+   This lexer copies the needed characters from the forward range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is slightly faster than `RangeLexer`, but shoudn't be used if a faster
+   lexer is available.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+/
struct ForwardLexer(T)
    if (isForwardRange!T)
{

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    //mixin UsesAllocator!Alloc;
    //mixin UsesErrorHandler!ErrorHandler;

    private size_t count;
    private CharacterType[] buffer;//private Appender!(CharacterType, Alloc) app;

    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        private typeof(input) input_start;
        void setSource(T input)
        {
            buffer.length = 0;//app = typeof(app)(allocator);
            this.input = input.representation;
            this.input_start = this.input;
        }
    }
    else
    {
        private T input;
        private T input_start;
        void setSource(T input)
        {
            buffer.length = 0;//app = typeof(app)(allocator);
            this.input = input;
            this.input_start = input;
        }
    }

    auto save()
    {
        ForwardLexer result;
        result.input = input.save();
        result.input_start = input.save();
        result.buffer.length = 0;//result.app = typeof(app)(allocator);
        result.count = count;
        return result;
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }

    /// ditto
    void start()
    {
        buffer.length = 0;

        input_start = input.save;
        count = 0;
    }

    /// ditto
    CharacterType[] get()
    {
        import std.range: take;
        auto diff = count - buffer.length;
        if (diff)
        {
            buffer.reserve(diff);
            buffer ~= input_start.take(diff);//app.put(input_start.take(diff));
        }
        return buffer;
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && indexOf(s, input.front) != -1)
        {
            input.popFront();
        }
        input_start = input.save;
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        enforce!LexerException(!input.empty , "No data found!");
        if (input.front == c)
        {
            count++;
            input.popFront();
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        enforce!LexerException(!input.empty
            , "No data found!");
        while (input.front != c)
        {
            count++;
            input.popFront();
            enforce!LexerException(!input.empty
                , "No data found!");
        }
        if (included)
        {
            count++;
            input.popFront();
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        enforce!LexerException(!input.empty
            , "No more characters are found!");
        size_t res;
        while ((res = indexOf(s, input.front)) == -1)
        {
            count++;
            input.popFront;
            enforce!LexerException(!input.empty
                , "No more characters are found!");
        }
        if (included)
        {
            count++;
            input.popFront;
        }
        return res;
    }
}

/++
+   A lexer that takes an InputRange of slices from the input.
+
+   This lexer tries to merge the speed of direct slicing with the low memory requirements
+   of ranges. Its input is a range whose elements are chunks of the input data; this
+   lexer returns slices of the original chunks, unless the output is split between two
+   chunks. If that's the case, a new array is allocated and returned. The various chunks
+   may have different sizes.
+
+   The bigger the chunks are, the better is the performance and higher the memory usage,
+   so finding the correct tradeoff is crucial for maximum performance. This lexer is
+   suitable for very large files, which are read chunk by chunk from the file system.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+/
struct BufferedLexer(T)
    if (isInputRange!T && isArray!(ElementType!T))
{
    //import newxml.appender;

    alias BufferType = ElementType!T;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!BufferType;
    /// ditto
    alias InputType = T;

    private InputType buffers;
    private size_t pos;
    private size_t begin;

    private CharacterType[] outBuf;//private Appender!(CharacterType, Alloc) app;
    private bool onEdge;

    private BufferType buffer;
    void popBuffer()
    {
        buffer = buffers.front;
        buffers.popFront;
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    void setSource(T input)
    {
        outBuf.length = 0; //app = typeof(app)(allocator);
        this.buffers = input;
        popBuffer;
    }

    static if (isForwardRange!T)
    {
        auto save() const
        {
            BufferedLexer result;
            result.buffers = buffers.save();
            result.buffer = buffer;
            result.pos = pos;
            result.begin = begin;
            result.outBuf.length = 0;//app = typeof(app)(allocator);
            return result;
        }
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    bool empty()
    {
        return buffers.empty && pos >= buffer.length;
    }

    /// ditto
    void start()
    {
        outBuf.length = 0;
        /+static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);+/

        begin = pos;
        onEdge = false;
    }

    private void advance()
    {
        enforce!LexerException(!empty
            , "No more characters are found!");
        if (pos + 1 >= buffer.length)
        {
            if (onEdge)
            {
                outBuf ~= buffer[pos];//app.put(buffer[pos]);
            }
            else
            {
                outBuf ~= buffer[begin..$];//app.put(buffer[begin..$]);
                onEdge = true;
            }
            popBuffer;
            begin = 0;
            pos = 0;
        }
        else if (onEdge)
        {
            outBuf ~= buffer[pos++];//app.put(buffer[pos++]);
        }
        else
        {
            pos++;
        }
    }
    private void advance(ptrdiff_t n)
    {
        foreach(i; 0..n)
        {
            advance();
        }
    }
    private void advanceNextBuffer()
    {
        enforce!LexerException(!empty
            , "No more characters are found!");
        if (onEdge)
        {
            outBuf ~= buffer[pos..$]; //app.put(buffer[pos..$]);
        }
        else
        {
            outBuf ~= buffer[begin..$];//app.put(buffer[begin..$]);
            onEdge = true;
        }
        popBuffer;
        begin = 0;
        pos = 0;
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`)
    +/
    CharacterType[] get() const
    {
        if (onEdge)
        {
            return outBuf;//app.data;
        }
        else
        {
            static if (is(typeof(representation!CharacterType(""))))
            {
                return cast(CharacterType[])buffer[begin..pos];
            }
            else
            {
                return buffer[begin..pos];
            }
        }
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!empty && indexOf(s, buffer[pos]) != -1)
        {
            advance();
        }
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        enforce!LexerException(!empty, "No data found!");
        if (buffer[pos] == c)
        {
            advance();
            return true;
        }

        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        enforce!LexerException(!empty, "No data found!");
        ptrdiff_t adv;
        while ((adv = indexOf(buffer[pos..$], c)) == -1)
        {
            advanceNextBuffer();
        }
        advance(adv);

        if (included)
        {
            advance();
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        enforce!LexerException(!empty, "No data found!");
        ptrdiff_t res;
        while ((res = indexOf(s, buffer[pos])) == -1)
        {
            advance();
        }

        if (included)
        {
            advance();
        }
        return res;
    }
}

/++
+   Instantiates a specialized lexer for the given input type.
+
+   The default error handler just asserts 0.
+   If the type of the allocator is specified as template parameter, but no instance of it
+   is passed as runtime parameter, then the static method `instance` of the allocator type is
+   used.
+/
auto chooseLexer(Input)()
{
    static if (is(SliceLexer!(Input)))
    {
        auto res = SliceLexer!(Input)();
        return res;
    }
    else static if (is(BufferedLexer!(Input)))
    {
        auto res = BufferedLexer!(Input)();
        return res;
    }
    else static if (is(RangeLexer!(Input)))
    {
        auto res = RangeLexer!(Input)();
        return res;
    }
    else
    {
        // TODO it would be good to know here why non of the three
        // lexer types could be chosen
        static assert(0);
    }

}

template lexer()
{
    auto lexer(Input)(auto ref Input input)
    {
        auto res = chooseLexer!(Input)();
        res.setSource(input);
        return res;
    }
}

version(unittest)
{
    struct DumbBufferedReader
    {
        string content;
        size_t chunk_size;

        void popFront() @nogc
        {
            content = content.length > chunk_size
                ? content[chunk_size..$]
                : [];
        }
        string front() const @nogc
        {
            return content.length >= chunk_size
                ? content[0..chunk_size]
                : content[0..$];
        }
        bool empty() const @nogc
        {
            return !content.length;
        }
    }
}

unittest
{
    void testLexer(T)(T.InputType delegate(string) @safe conv) @safe
    {
        string xml = q{
        <?xml encoding = "utf-8" ?>
        <aaa xmlns:myns="something">
            <myns:bbb myns:att='>'>
                <!-- lol -->
                Lots of Text!
                On multiple lines!
            </myns:bbb>
            <![CDATA[ Ciaone! ]]>
            <ccc/>
        </aaa>
        };

        T lexer;
        assert(lexer.empty);
        lexer.setSource(conv(xml));

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny(":>", true);
        assert(lexer.get() == "<?xml encoding = \"utf-8\" ?>");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny("=:", false);
        assert(lexer.get() == "<aaa xmlns");

        lexer.start();
        lexer.advanceUntil('>', true);
        assert(lexer.get() == ":myns=\"something\">");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntil('\'', true);
        assert(lexer.testAndAdvance('>'));
        lexer.advanceUntil('>', false);
        assert(lexer.testAndAdvance('>'));
        assert(lexer.get() == "<myns:bbb myns:att='>'>");

        assert(!lexer.empty);
    }

    testLexer!(SliceLexer!(string))(x => x);
    testLexer!(RangeLexer!(string))(x => x);
    testLexer!(ForwardLexer!(string))(x => x);
    testLexer!(BufferedLexer!(DumbBufferedReader))(x => DumbBufferedReader(x, 10));
}

