/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements fast search and compare
+   functions on slices. In the future, these may be
+   optimized by means of aggressive specialization,
+   inline assembly and SIMD instructions.
+/

module newxml.faststrings;

import std.algorithm.comparison : equal;
import std.exception : enforce;
import std.string;

import newxml.interfaces : XMLException;

package bool checkStringBeforeChr(T, S)(T[] haysack, S[] needle, S before) @nogc @safe pure nothrow
{
    for (sizediff_t i ; i < haysack.length ; i++) {
        if (haysack[i] == needle[0])
        {
            return (cast(sizediff_t)(haysack.length) - i > needle.length) 
                ? equal(haysack[i..i + needle.length], needle)
                : false;
        }
        else if (haysack[i] == before)
            return false;
    }
    return false;
}
unittest 
{
    assert(checkStringBeforeChr("extentity SYSTEM \"someexternalentity.file\"", "SYSTEM", '"'));
    assert(!checkStringBeforeChr("extentity SYST", "SYSTEM", '"'));
    assert(!checkStringBeforeChr("intentity \"Some internal entity\"", "SYSTEM", '"'));
}

/++
+   Returns a copy of the input string, after escaping all XML reserved characters.
+
+   If the string does not contain any reserved character, it is returned unmodified;
+   otherwise, a copy is made using the specified allocator.
+/
T[] xmlEscape(T)(T[] str)
{
    if (str.indexOfAny("&<>'\"") >= 0)
    {
        //import newxml.appender;

        T[] app; //auto app = Appender!(T, Alloc)(alloc);
        app.reserve(str.length + 3);

        app.xmlEscapedWrite(str);
        return app;
    }
    return str;
}

/++
+   Writes the input string to the given output range, after escaping all XML reserved characters.
+/
void xmlEscapedWrite(Out, T)(ref Out output, T[] str)
{
    import std.conv : to;
    static immutable amp = to!(T[])("&amp;");
    static immutable lt = to!(T[])("&lt;");
    static immutable gt = to!(T[])("&gt;");
    static immutable apos = to!(T[])("&apos;");
    static immutable quot = to!(T[])("&quot;");

    ptrdiff_t i;
    while ((i = str.indexOfAny("&<>'\"")) >= 0)
    {
        output ~= str[0..i];

        if (str[i] == '&')
            output ~= amp;
        else if (str[i] == '<')
            output ~= lt;
        else if (str[i] == '>')
            output ~= gt;
        else if (str[i] == '\'')
            output ~= apos;
        else if (str[i] == '"')
            output ~= quot;

        str = str[i+1..$];
    }
    output ~= str;
}

auto xmlPredefinedEntities(T)() {
    alias STR = T[];
    STR[STR] result;
    result["amp"] = "&";
    result["lt"] = "<";
    result["gt"] = ">";
    result["apos"] = "'";
    result["quot"] = "\"";
    
    return result;
}

import std.typecons: Flag, Yes;

/++
+   Returns a copy of the input string, after unescaping all known entity references.
+
+   If the string does not contain any entity reference, it is returned unmodified;
+   otherwise, a copy is made using the specified allocator.
+
+   The set of known entities can be specified with the last parameter, which must support
+   the `in` operator (it is treated as an associative array).
+/
T[] xmlUnescape(Flag!"strict" strict = Yes.strict, T, U)(T[] str, U replacements)
{
    if (str.indexOf('&') >= 0)
    {
        //import newxml.appender;

        T[] app;//auto app = Appender!(T, Alloc)(alloc);
        app.reserve(str.length);

        app.xmlUnescapedWrite!strict(str, replacements);
        return app;
    }
    return str;
}
T[] xmlUnescape(Flag!"strict" strict = Yes.strict, T)(T[] str)
{
    if (str.indexOf('&') >= 0)
    {
        //import newxml.appender;

        T[] app;//auto app = Appender!(T, Alloc)(alloc);
        app.reserve(str.length);

        app.xmlUnescapedWrite!strict(str, xmlPredefinedEntities!T());
        return app;
    }
    return str;
}

/++
+   Outputs the input string to the given output range, after unescaping all known entity references.
+
+   The set of known entities can be specified with the last parameter, which must support
+   the `in` operator (it is treated as an associative array).
+/
void xmlUnescapedWrite(Flag!"strict" strict = Yes.strict, Out, T, U)
                      (ref Out output, T[] str, U replacements)
{
    ptrdiff_t i;
    while ((i = str.indexOf('&')) >= 0)
    {
        output ~= str[0..i];

        ptrdiff_t j = str[(i+1)..$].indexOf(';');
        static if (strict == Yes.strict)
        {
            enforce!XMLException(j >= 0, "Missing ';' ending XML entity!");
        }
        else 
        {
            if (j < 0) continue;
        }
        auto ent = str[(i+1)..(i+j+1)];
        static if (strict == Yes.strict)
        {
            enforce!XMLException(ent.length, "Character replacement entity not found!");
        }
        else
        {
            if (!ent.length) continue;
        }

        // character entities
        if (ent[0] == '#')
        {
            //assert(ent.length > 1);
            ulong num;
            // hex number
            if (ent.length > 2 && ent[1] == 'x')
            {
                static if (strict == Yes.strict)
					enforce!XMLException(ent.length <= 10
							, "Number escape value is too large!");
                foreach(digit; ent[2..$])
                {
                    if ('0' <= digit && digit <= '9')
                        num = (num << 4) + (digit - '0');
                    else if ('a' <= digit && digit <= 'f')
                        num = (num << 4) + (digit - 'a' + 10);
                    else if ('A' <= digit && digit <= 'F')
                        num = (num << 4) + (digit - 'A' + 10);
                    else
                    {
                        static if (strict == Yes.strict)
                            throw new XMLException("Wrong character encountered within hexadecimal number!");
                        else
                            break;
                    }
                }
            }
            // decimal number
            else
            {
                static if (strict == Yes.strict)
                    enforce!XMLException(ent.length <= 12, "Number escape value is too large!");
                foreach(digit; ent[1..$])
                {
                    if ('0' <= digit && digit <= '9')
                    {
                        num = (num * 10) + (digit - '0');
                    }
                    else
                        static if (strict == Yes.strict)
                            throw new XMLException("Wrong character encountered within decimal number!");
                        else
                            break;
                }
            }
            static if (strict == Yes.strict)
				enforce!XMLException(num <= 0x10FFFF
						, "Number escape value is too large!");

            output ~= cast(dchar)num;
        }
        // named entities
        else
        {
            auto repl = replacements.get(ent, null);
            static if (strict == Yes.strict)
            {
                enforce!XMLException(repl
						, "Character replacement entity not found!");
            }
            else
            {
                if (!repl)
                {
                    output ~= str[i];
                    str = str[(i+1)..$];
                    continue;
                }
            }
            output ~= repl;
        }

        str = str[(i+j+2)..$];
    }
    output ~= str;
}

unittest
{
    //import std.experimental.allocator.mallocator;//import stdx.allocator.mallocator;
    //auto alloc = Mallocator.instance;
    assert(xmlEscape("some standard string"d) == "some standard string"d);
    assert(xmlEscape("& \"some\" <standard> 'string'") ==
                     "&amp; &quot;some&quot; &lt;standard&gt; &apos;string&apos;");
    assert(xmlEscape("<&'>>>\"'\"<&&"w) ==
                     "&lt;&amp;&apos;&gt;&gt;&gt;&quot;&apos;&quot;&lt;&amp;&amp;"w);
}

unittest
{
    import std.exception : assertThrown;
    assert(xmlUnescape("some standard string"d) == "some standard string"d);
    assert(xmlUnescape("some s&#116;range&#x20;string") == "some strange string");
    assert(xmlUnescape("&amp; &quot;some&quot; &lt;standard&gt; &apos;string&apos;")
                       == "& \"some\" <standard> 'string'");
    assert(xmlUnescape("&lt;&amp;&apos;&gt;&gt;&gt;&quot;&apos;&quot;&lt;&amp;&amp;"w)
                       == "<&'>>>\"'\"<&&"w);
    assert(xmlUnescape("Illegal markup (&lt;% ... %&gt;)") == "Illegal markup (<% ... %>)");
    assertThrown!XMLException(xmlUnescape("Fa&#xFF000000F6;il"));
    assertThrown!XMLException(xmlUnescape("Fa&#68000000000;il"));
}
