/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

// TODO: write an in-depth explanation of this module, how to create validations,
// how validations should behave, etc...

/++
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

module newxml.validation;

import newxml.interfaces;

/**
*   Checks whether a character can appear in an XML 1.0 document.
*/
pure nothrow @nogc @safe bool isValidXMLCharacter10(dchar c)
{
    return c == '\r' || c == '\n' || c == '\t'
        || (0x20 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}

/**
*   Checks whether a character can appear in an XML 1.1 document.
*/
pure nothrow @nogc @safe bool isValidXMLCharacter11(dchar c)
{
    return (1 <= c && c <= 0xD7FF)
        || (0xE000 <= c && c <= 0xFFFD)
        || (0x10000 <= c && c <= 0x10FFFF);
}
/**
 * Checks whether a text contains invalid characters for an XML 1.0 document.
 * Params:
 *   input = The text to test for.
 * Returns: true if text doesn't contain any invalid characters.
 */
pure nothrow @nogc @safe bool isValidXMLText10(T)(T[] input)
{
    foreach (elem; input)
    {
        if (!isValidXMLCharacter10(elem)) return false;
    }
    return true;
}
/**
 * Checks whether a text contains invalid characters for an XML 1.1 document.
 * Params:
 *   input = The text to test for.
 * Returns: true if text doesn't contain any invalid characters.
 */
pure nothrow @nogc @safe bool isValidXMLText11(T)(T[] input)
{
    foreach (elem; input)
    {
        if (!isValidXMLCharacter11(elem)) return false;
    }
    return true;
}

/**
*   Checks whether a character can start an XML name (tag name or attribute name).
*/
pure nothrow @nogc @safe bool isValidXMLNameStart(dchar c)
{
    return c == ':'
        || ('A' <= c && c <= 'Z')
        || c == '_'
        || ('a' <= c && c <= 'z')
        || (0xC0 <= c && c <= 0x2FF && c != 0xD7 && c != 0xF7)
        || (0x370 <= c && c <= 0x1FFF && c != 0x37E)
        || c == 0x200C
        || c == 0x200D
        || (0x2070 <= c && c <= 0x218F)
        || (0x2C00 <= c && c <= 0x2FEF)
        || (0x3001 <= c && c <= 0xD7FF)
        || (0xF900 <= c && c <= 0xFDCF)
        || (0xFDF0 <= c && c <= 0xEFFFF && c != 0xFFFE && c != 0xFFFF);
}

/**
*   Checks whether a character can appear inside an XML name (tag name or attribute name).
*/
pure nothrow @nogc @safe bool isValidXMLNameChar(dchar c)
{
    return isValidXMLNameStart(c)
        || c == '-'
        || c == '.'
        || ('0' <= c && c <= '9')
        || c == 0xB7
        || (0x300 <= c && c <= 0x36F)
        || (0x203F <= c && c <= 2040);
}

/**
 * Checks whether a name is a valid XML name or not.
 * Params:
 *   input = The input string.
 * Returns: True if XML name is valid.
 */
pure nothrow @nogc @safe bool isValidXMLName(T)(T[] input) {
    if (!input.length)
    {
        return false;
    }
    if (!isValidXMLNameStart(input[0]))
    {
        return false;
    }

    for (sizediff_t i = 1 ; i < input.length; i++)
    {
        if (!isValidXMLNameChar(input[i]))
        {
            return false;
        }
    }

    return true;
}

/**
*   Checks whether a character can appear in an XML public ID.
*/
pure nothrow @nogc @safe bool isValidXMLPublicIdCharacter(dchar c)
{
    import std.string: indexOf;
    return c == ' '
        || c == '\n'
        || c == '\r'
        || ('a' <= c && c <= 'z')
        || ('A' <= c && c <= 'Z')
        || ('0' <= c && c <= '9')
        || "-'()+,./:=?;!*#@$_%".indexOf(c) != -1;
}

unittest
{
    assert(isValidXMLName("foo"));
    assert(isValidXMLName("bar"));
    assert(!isValidXMLName(".foo"));
    assert(isValidXMLName("foo:bar"));
}

/**
 * A simple document validation stack.
 * Node names on every non-empty starting nodes are pushed here, then on every ending node the top is popped then
 * compared with the name.
 */
struct ValidationStack(StringType)
{
    StringType[] stack;
    /**
     * Pushes a name to the top.
     */
    void push(StringType input) @safe pure nothrow
    {
        stack ~= input;
    }
    /**
     * Pops a name from the top, then compared with the input.
     * Params:
     *   input = the string that is being compared with the input.
     * Returns: True if a string could been removed from the stack and it's identical with the input, false otherwise.
     */
    bool pop(StringType input) @safe pure nothrow
    {
        if (stack.length)
        {
            StringType top = stack[$-1];
            stack = stack[0..$-1];
            return top == input;
        }
        else
        {
            return false;
        }
    }
}
