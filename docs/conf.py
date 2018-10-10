import sphinx_rtd_theme
from recommonmark.parser import CommonMarkParser

project = 'SCRAM'

html_theme = 'sphinx_rtd_theme'

html_theme_path = [sphinx_rtd_theme.get_html_theme_path()]

source_parsers = {
    '.md': CommonMarkParser,
}

source_suffix = ['.rst', '.md']

master_doc = 'index'


def setup(app):
    app.add_stylesheet('css/styles.css')
