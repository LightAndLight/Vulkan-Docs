# Copyright 2026 The Khronos Group Inc.
#
# SPDX-License-Identifier: Apache-2.0

# manpage-converter - customizes the Asciidoctor manpage converter for
# roff refpages built with 'make manpages'.

require 'asciidoctor' unless RUBY_ENGINE == 'opal'

class VulkanManPageConverter < (Asciidoctor::Converter.for 'manpage')
    register_for 'manpage'

    # Link to another refpage, as written by genRef.py
    RefpageLinkRx = /\A([\w-]+)\.html\z/

    # Allow URL line breaks after '/' and '#'
    UrlBreakRx = %r{(/(?!/)|#)}

    def convert_inline_anchor node
        return super unless node.type == :link

        target = node.target
        text = node.text

        # Refpage links become man page cross-references
        if (match = RefpageLinkRx.match target)
            name = match[1]
            page = %(<#{ESC_BS}fB>#{ESC_BS}%#{name}</#{ESC_BS}fP>(3))
            return text == name ? page : %(#{text} (#{page}))
        end

        # Other links are written inline, since the www.tmac URL macro used
        # by the base converter does not break long URLs
        return super if target.start_with? 'mailto:'
        url = %(#{ESC_BS}%<#{target.gsub(UrlBreakRx) { %(#{$1}#{ESC_BS}:) }}>)
        text == target ? url : %(#{text} #{url})
    end

    # Show math blocks as unfilled LaTeX source
    def convert_stem node
        result = []
        result << %(.sp
.B #{manify node.title}
.br) if node.title?
        open, close = BLOCK_MATH_DELIMITERS[node.style.to_sym]
        equation = node.content
        if (equation.start_with? open) && (equation.end_with? close)
            equation = equation.slice open.length, equation.length - open.length - close.length
        end
        result << %(.sp
.if n .RS 4
.nf
#{manify equation.strip, whitespace: :preserve}
.fi
.if n .RE)
        result.join LF
    end

    def manify str, opts = {}
        # Word joiner - block form, since '\\&' would be a backreference
        super str.gsub('&#8288;') { %(#{ESC_BS}&) }, opts
    end

    def convert_document node
        # Keep text left-adjusted, since groff man macros reset adjustment
        # to AD at each paragraph, and disable the 'break' warning (4) for
        # unhyphenated API names longer than the line
        super.sub(/^\.ad l$/, %(.ad l
.ds AD l
.if \\n[.g] .warn \\n[.warn]-(\\n[.warn]/4%2*4)))
    end
end
