Introduction page
=======================================

https://github.com/jonasdaugalas/brilview/tree/master/docs

https://github.com/rtfd/readthedocs.org/blob/master/docs/index.rst

First steps
-----------

This is example layout to check it it is posible to mix .rst and .md files in one
documentation.

* **Refering to other document**:
  :doc:`document <dir1/text1>`

.. toctree::
   :maxdepth: 3
   :hidden:
   :caption: This is example of constructing document tree

   dir1/getting-started-with-sphinx
   README
   Top_level
