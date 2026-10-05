#!/usr/bin/env python3
#
# Copyright 2020-2026 The Khronos Group Inc.
#
# SPDX-License-Identifier: Apache-2.0
"""Script to create symbolic links for aliases in reference pages
   Usage: makemanaliases.py -refdir refpage-output-directory [-suffix .3 -so]"""

import argparse
import os
import sys

if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument('-genpath', action='store',
                        default=None,
                        help='Path to directory containing generated apimap.py module')
    parser.add_argument('-refdir', action='store',
                        required=True,
                        help='Path to directory containing reference pages to symlink')
    parser.add_argument('-suffix', action='store',
                        default='.html',
                        help='File suffix of reference pages (default .html)')
    parser.add_argument('-so', action='store_true',
                        help='Create roff .so stub pages instead of symlinks')

    args = parser.parse_args()

    # Look for apimap.py in the specified directory
    if args.genpath is not None:
        sys.path.insert(0, args.genpath)
    import apimap as api

    # Change to refpage directory
    try:
        os.chdir(args.refdir)
    except:
        print('Cannot chdir to', args.refdir, file=sys.stderr)
        sys.exit(1)

    # For each alias in the API alias map, create a symlink if it
    # does not exist - and warn if it does exist.

    for key in api.alias:
        if key.endswith(('_EXTENSION_NAME', '_SPEC_VERSION')):
            # No reference pages are generated for these meta-tokens, so
            # attempts to alias them will fail. Silently skip them.
            continue

        alias = f"{key}{args.suffix}"
        src = f"{api.alias[key]}{args.suffix}"

        if not os.access(src, os.R_OK):
            # This should not happen, but is possible if the api module is
            # not generated for the same set of APIs as were the refpages.
            print('No source file', src, file=sys.stderr)
            continue

        # .so paths are relative to the top of the man page hierarchy
        stub = f'.so {os.path.basename(os.getcwd())}/{src}\n'

        if os.access(alias, os.R_OK):
            # A stub left by a previous build is fine
            if args.so and not os.path.islink(alias):
                with open(alias, encoding='utf-8') as fp:
                    if fp.read() == stub:
                        continue

            # If the link already exists, that is not necessarily a
            # problem, so do not fail, but it should be checked out.
            # The usual case for this is not cleaning the target directory
            # prior to generating refpages.
            print(f"Unexpected alias file \"{alias}\" exists, skipping",
                  file=sys.stderr)
        elif args.so:
            with open(alias, 'w', encoding='utf-8') as fp:
                fp.write(stub)
        else:
            # Create link from alias refpage to page for what it is aliasing
            os.symlink(src, alias)
