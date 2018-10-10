# SCRAM documentation

[This folder](https://github.com/cms-sw/SCRAM/tree/master/docs) contains source code for SCRAM documentation hosted [Read The docs](http://scram.readthedocs.io).

## Why Read The docs

After trying multiple documentation software, we chose RTD because:

* We are able to write content in Markdown and reStructuredText syntax;
* It has strong search functionality;
* Ability to version documentation, create PDF files, etc. ;
* Ability to use hosting service for free;
* Benefits of static page generator;
* Possibility for themes;
* Ability to keep documentation with source code.

## Setup

This setup is using `Sphinx` as a backend to generate pages which, by default, process `.rst` documents.
We are also using `recommonmark` extension to digest `.md` documents. This setup allows document in any file format we wish while keeping benefits of using `Sphinx` generator.

## Editing documentation

* `conf.py` - this is config path for changing styles, paths, etc. ;
* `index.rst` - basically Table of content/main page. After creating new document do not forget to include its path here.

Just edit documents following Markdown or reStructuredText syntax. If creating new document or you want to change order in TOC, do not forget to edit `index.rst` file.

## Local development

To develop documentation locally:

```bash
# in the current path
python -m virtualenv /tmp/_env/rtd
source /tmp/_env/rtd/bin/activate
pip install -r requirements.txt
make html
deactivate # deactivates virtual enviroment
```

## Format MAN pages to Markdown

In case you need convert existing MAN pages (`.roff` extension), check [this project](https://github.com/mle86/man-to-md).
It is not perfect, so look at the workaround in [this issue](https://github.com/mle86/man-to-md/issues/1).

Example command:

```bash
./man-to-md.pl ../SCRAM/docs/man/scram.1.in > ../SCRAM/docs/man/scram-man.md
```

## More info

* [Read The Docs documentation](https://docs.readthedocs.io)
* Examples:
    * [brilview](https://github.com/jonasdaugalas/brilview/tree/master/docs)
    * [Read The Docs source](https://github.com/rtfd/readthedocs.org/blob/master/docs/index.rst)