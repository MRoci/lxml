
cdef extern from "libxml/tree.h":
    ctypedef enum xmlElementType:
        XML_ELEMENT_NODE=           1
        XML_ATTRIBUTE_NODE=         2
        XML_TEXT_NODE=              3
        XML_CDATA_SECTION_NODE=     4
        XML_ENTITY_REF_NODE=        5
        XML_ENTITY_NODE=            6
        XML_PI_NODE=                7
        XML_COMMENT_NODE=           8
        XML_DOCUMENT_NODE=          9
        XML_DOCUMENT_TYPE_NODE=     10
        XML_DOCUMENT_FRAG_NODE=     11
        XML_NOTATION_NODE=          12
        XML_HTML_DOCUMENT_NODE=     13
        XML_DTD_NODE=               14
        XML_ELEMENT_DECL=           15
        XML_ATTRIBUTE_DECL=         16
        XML_ENTITY_DECL=            17
        XML_NAMESPACE_DECL=         18
        XML_XINCLUDE_START=         19
        XML_XINCLUDE_END=           20

    ctypedef struct xmlDoc
    ctypedef struct xmlAttr
    ctypedef struct xmlDict
    
    ctypedef struct xmlNode:
        xmlElementType   type
        char   *name
        xmlNode *children
        xmlNode *last
        xmlNode *parent
        xmlNode *next
        xmlNode *prev
        xmlDoc *doc
        char *content
        xmlAttr* properties
        
    ctypedef struct xmlDoc:
        xmlElementType type
        char *name
        xmlNode *children
        xmlNode *last
        xmlNode *parent
        xmlNode *next
        xmlNode *prev
        xmlDoc *doc
        xmlDict* dict
        
    ctypedef struct xmlNs:
        char* href
        char* prefix
        
    ctypedef struct xmlAttr:
        xmlElementType type
        char* name
        xmlNode* children
        xmlNode* last
        xmlNode* parent
        xmlNode* next
        xmlNode* prev
        xmlDoc* doc

    ctypedef struct xmlParserCtxt:
        xmlDoc* myDoc
        xmlDict* dict
        int wellFormed
 
    cdef void xmlFreeDoc(xmlDoc *cur)
    cdef xmlNode* xmlNewNode(xmlNs* ns, char* name)
    cdef xmlNode* xmlAddChild(xmlNode* parent, xmlNode* cur)
    cdef xmlNode* xmlNewDocNode(xmlDoc* doc, xmlNs* ns,
                                char* name, char* content)
    cdef xmlDoc* xmlNewDoc(char* version)
    cdef xmlAttr* xmlNewProp(xmlNode* node, char* name, char* value)
    cdef char* xmlGetNoNsProp(xmlNode* node, char* name)
    cdef void xmlSetProp(xmlNode* node, char* name, char* value)
    cdef void xmlDocDumpMemory(xmlDoc* cur,
                               char** mem,
                               int* size)
    cdef void xmlFree(char* buf)
    cdef void xmlUnlinkNode(xmlNode* cur)
    cdef xmlNode* xmlDocSetRootElement(xmlDoc* doc, xmlNode* root)
    cdef xmlNode* xmlDocGetRootElement(xmlDoc* doc)
    cdef void xmlSetTreeDoc(xmlNode* tree, xmlDoc* doc)
    cdef xmlNode* xmlDocCopyNode(xmlNode* node, xmlDoc* doc, int extended)

cdef extern from "libxml/dict.h":
    cdef xmlDict* xmlDictFree(xmlDict* sub)
    cdef int xmlDictReference(xmlDict* dict)

cdef extern from "libxml/parser.h":
    
    ctypedef enum xmlParserOption:
        XML_PARSE_RECOVER = 1 # recover on errors
        XML_PARSE_NOENT = 2 # substitute entities
        XML_PARSE_DTDLOAD = 4 # load the external subset
        XML_PARSE_DTDATTR = 8 # default DTD attributes
        XML_PARSE_DTDVALID = 16 # validate with the DTD
        XML_PARSE_NOERROR = 32 # suppress error reports
        XML_PARSE_NOWARNING = 64 # suppress warning reports
        XML_PARSE_PEDANTIC = 128 # pedantic error reporting
        XML_PARSE_NOBLANKS = 256 # remove blank nodes
        XML_PARSE_SAX1 = 512 # use the SAX1 interface internally
        XML_PARSE_XINCLUDE = 1024 # Implement XInclude substitition
        XML_PARSE_NONET = 2048 # Forbid network access
        XML_PARSE_NODICT = 4096 # Do not reuse the context dictionnary
        XML_PARSE_NSCLEAN = 8192 # remove redundant namespaces declarations
        XML_PARSE_NOCDATA = 16384 # merge CDATA as text nodes
        XML_PARSE_NOXINCNODE = 32768 # do not generate XINCLUDE START/END nodes
       
    cdef void xmlInitParser()
    cdef xmlParserCtxt* xmlCreateDocParserCtxt(char* cur)
    cdef int xmlCtxtUseOptions(xmlParserCtxt* ctxt, int options)
    cdef int xmlParseDocument(xmlParserCtxt* ctxt)
    cdef void xmlFreeParserCtxt(xmlParserCtxt* ctxt)
    
    cdef xmlDoc* xmlParseDoc(char* cur)

# the rules
# any libxml C argument/variable is prefixed with c_
# any non-public function/class is prefixed with an underscore
# instance creation is always through factories

cdef class _DocumentBase:
    """Base class to reference a libxml document.

    When instances of this class are garbage collected, the libxml
    document is cleaned up.
    """
    
    cdef xmlDoc* _c_doc

    def __dealloc__(self):
        xmlFreeDoc(self._c_doc)
    
cdef class _NodeBase:
    """Base class to reference a document object and a libxml node.

    By pointing to an ElementTree instance, a reference is kept to
    _ElementTree as long as there is some pointer to a node in it.
    """
    cdef _DocumentBase _doc
    cdef xmlNode* _c_node

cdef class _ElementTree(_DocumentBase):
    def getroot(self):
        cdef xmlNode* c_node
        c_node = xmlDocGetRootElement(self._c_doc)
        if c_node is NULL:
            return # return None
        return _elementFactory(self, c_node)
    
    def write(self, file, encoding='us-ascii'):
        # XXX dumping to memory first is definitely not the most efficient
        cdef char* mem
        cdef int size
        xmlDocDumpMemory(self._c_doc, &mem, &size)
        if encoding in ('UTF-8', 'utf8', 'UTF8', 'utf-8'):
            file.write(mem)
        else:
            file.write(unicode(mem, 'UTF-8').encode(encoding))
        xmlFree(mem)
        
cdef _ElementTree _elementTreeFactory(xmlDoc* c_doc):
    cdef _ElementTree result
    result = _ElementTree()
    result._c_doc = c_doc
    return result
    
cdef class _Element(_NodeBase):
    # MANIPULATORS
    def set(self, key, value):
        self.attrib[key] = value

    def append(self, _Element element):
        # XXX what if element is coming from a different document?
        xmlUnlinkNode(element._c_node)
        xmlAddChild(self._c_node, element._c_node)
        element._doc = self._doc

    # PROPERTIES
    property tag:
        def __get__(self):
            return unicode(self._c_node.name, 'UTF-8')

    property attrib:
        def __get__(self):
            return _attribFactory(self._doc, self._c_node)
        
    property text:
        def __get__(self):
            cdef xmlNode* c_node
            c_node = self._c_node.children
            if c_node is NULL:
                return None
            if c_node.type != XML_TEXT_NODE:
                return None
            return unicode(c_node.content, 'UTF-8')

        def __set__(self, value):
            pass

    property tail:
        def __get__(self):
            cdef xmlNode* c_node
            c_node = self._c_node.next
            if c_node is NULL:
                return None
            if c_node.type != XML_TEXT_NODE:
                return None
            return unicode(c_node.content, 'UTF-8')

    # ACCESSORS
    def __getitem__(self, n):
        cdef xmlNode* c_node
        c_node = self._c_node.children
        c = 0
        while c_node is not NULL:
            if c_node.type == XML_ELEMENT_NODE:
                if c == n:
                    return _elementFactory(self._doc, c_node)
                c = c + 1
            c_node = c_node.next
        else:
            raise IndexError

    def __len__(self):
        cdef int c
        cdef xmlNode* c_node
        c = 0
        c_node = self._c_node.children
        while c_node is not NULL:
            if c_node.type == XML_ELEMENT_NODE:
                c = c + 1
            c_node = c_node.next
        return c

    def __iter__(self):
        return _elementIteratorFactory(self._doc, self._c_node.children)
    
    def get(self, key, default=None):
        return self.attrib.get(key, default)

    def keys(self):
        return self.attrib.keys()

    def items(self):
        return self.attrib.items()
    
cdef _Element _elementFactory(_ElementTree tree, xmlNode* c_node):
    cdef _Element result
    if c_node is NULL:
        return None
    result = _Element()
    result._doc = tree
    result._c_node = c_node
    return result

cdef class _Attrib(_NodeBase):
    # MANIPULATORS
    def __setitem__(self, key, value):
        key = key.encode('UTF-8')
        value = value.encode('UTF-8')
        xmlSetProp(self._c_node, key, value)

    # ACCESSORS
    def __getitem__(self, key):
        cdef char* result
        key = key.encode('UTF-8')
        result = xmlGetNoNsProp(self._c_node, key)
        if result is NULL:
            raise KeyError, key
        return unicode(result, 'UTF-8')

    def __len__(self):
        cdef int c
        cdef xmlNode* c_node
        c = 0
        c_node = <xmlNode*>(self._c_node.properties)
        while c_node is not NULL:
            if c_node.type == XML_ATTRIBUTE_NODE:
                c = c + 1
            c_node = c_node.next
        return c
    
    def get(self, key, default=None):
        try:
            return self.__getitem__(key)
        except KeyError:
            return default

    def __iter__(self):
        return _attribIteratorFactory(self._doc,
                                      <xmlNode*>self._c_node.properties)
    
    def keys(self):
        result = []
        cdef xmlNode* c_node
        c_node = <xmlNode*>(self._c_node.properties)
        while c_node is not NULL:
            if c_node.type == XML_ATTRIBUTE_NODE:
                result.append(unicode(c_node.name, 'UTF-8'))
            c_node = c_node.next
        return result

    def values(self):
        result = []
        cdef xmlNode* c_node
        c_node = <xmlNode*>(self._c_node.properties)
        while c_node is not NULL:
            if c_node.type == XML_ATTRIBUTE_NODE:
                result.append(
                    unicode(xmlGetNoNsProp(self._c_node, c_node.name), 'UTF-8')
                    )
            c_node = c_node.next
        return result
        
    def items(self):
        result = []
        cdef xmlNode* c_node
        c_node = <xmlNode*>(self._c_node.properties)
        while c_node is not NULL:
            if c_node.type == XML_ATTRIBUTE_NODE:
                result.append((
                    unicode(c_node.name, 'UTF-8'),
                    unicode(xmlGetNoNsProp(self._c_node, c_node.name), 'UTF-8')
                    ))
            c_node = c_node.next
        return result
    
cdef _Attrib _attribFactory(_ElementTree tree, xmlNode* c_node):
    cdef _Attrib result
    result = _Attrib()
    result._doc = tree
    result._c_node = c_node
    return result

cdef class _AttribIterator(_NodeBase):
    def __next__(self):
        cdef xmlNode* c_node
        c_node = self._c_node
        while c_node is not NULL:
            if c_node.type == XML_ATTRIBUTE_NODE:
                break
            c_node = c_node.next
        else:
            raise StopIteration
        self._c_node = c_node.next
        return unicode(c_node.name, 'UTF-8')

cdef _AttribIterator _attribIteratorFactory(_ElementTree tree,
                                            xmlNode* c_node):
    cdef _AttribIterator result
    result = _AttribIterator()
    result._doc = tree
    result._c_node = c_node
    return result

cdef class _ElementIterator(_NodeBase):
    def __next__(self):
        cdef xmlNode* c_node
        c_node = self._c_node
        while c_node is not NULL:
            if c_node.type == XML_ELEMENT_NODE:
                break
            c_node = c_node.next
        else:
            raise StopIteration
        self._c_node = c_node.next
        return _elementFactory(self._doc, c_node)

cdef _ElementIterator _elementIteratorFactory(_ElementTree tree,
                                              xmlNode* c_node):
    cdef _ElementIterator result
    result = _ElementIterator()
    result._doc = tree
    result._c_node = c_node
    return result

cdef xmlNode* _createElement(xmlDoc* c_doc, char* tag,
                             object attrib, object extra):
    cdef xmlNode* c_node
    if attrib is None:
        attrib = {}
    attrib.update(extra)
    c_node = xmlNewDocNode(c_doc, NULL, tag, NULL)
    for name, value in attrib.items():
        xmlNewProp(c_node, name, value)
    return c_node
    
def Element(tag, attrib=None, **extra):
    cdef xmlNode* c_node
    cdef _ElementTree tree

    tree = ElementTree()
    c_node = _createElement(tree._c_doc, tag, attrib, extra)
    xmlDocSetRootElement(tree._c_doc, c_node)
    return _elementFactory(tree, c_node)

def SubElement(_Element parent, tag, attrib=None, **extra):
    cdef xmlNode* c_node
    cdef _Element element
    c_node = _createElement(parent._doc._c_doc, tag, attrib, extra)
    element = _elementFactory(parent._doc, c_node)
    parent.append(element)
    return element

def ElementTree(_Element element=None, file=None):
    cdef xmlDoc* c_doc
    cdef xmlNode* c_node
    cdef xmlNode* c_node_copy
    cdef _ElementTree tree
    
    if file is not None:
        # XXX read XML into memory not the fastest way to do this
        data = file.read()
        c_doc = theParser.parseDoc(data)
    else:
        c_doc = theParser.newDoc()
    
    tree = _elementTreeFactory(c_doc)

    # XXX what if element and file are both not None?
    if element is not None:
        # XXX we'd prefer not having to make a copy
        # XXX but moving it causes a segfault when doing xmlFreeDoc
        c_node_copy = xmlDocCopyNode(element._c_node, tree._c_doc, 1)
        xmlDocSetRootElement(tree._c_doc, c_node_copy)
        element._c_node = c_node_copy
        element._doc = tree
    return tree

cdef class Parser:

    cdef xmlDict* _c_dict

    def __init__(self):
        self._c_dict = NULL

    def __del__(self):
        if self._c_dict is not NULL:
            xmlDictFree(self._c_dict)
        
    cdef xmlDoc* parseDoc(self, text):
        """Parse document, share dictionary if possible.
        """
        cdef xmlDoc* result
        cdef xmlParserCtxt* pctxt

        xmlInitParser()
        pctxt = xmlCreateDocParserCtxt(text)
        
        if self._c_dict is not NULL and pctxt.dict is not NULL:
            xmlDictFree(pctxt.dict)
            pctxt.dict = self._c_dict
            xmlDictReference(pctxt.dict)

        # parse with the following options
        # * substitute entities
        # * no network access
        # * no cdata nodes
        xmlCtxtUseOptions(
            pctxt,
            XML_PARSE_NOENT | XML_PARSE_NOENT | XML_PARSE_NOCDATA)

        xmlParseDocument(pctxt)

        if pctxt.wellFormed:
            result = pctxt.myDoc

            # store dict of last object parsed if no shared dict yet
            if self._c_dict is NULL:
                self._c_dict = result.dict
                xmlDictReference(self._c_dict)
        else:
            result = NULL
            if pctxt.myDoc is not NULL:
                xmlFreeDoc(pctxt.myDoc)
            pctxt.myDoc = NULL
        xmlFreeParserCtxt(pctxt)

        return result

    cdef xmlDoc* newDoc(self):
        cdef xmlDoc* result
        
        result = xmlNewDoc("1.0")
        if self._c_dict is not NULL and result.dict is not NULL:
            xmlDictFree(result.dict)
            result.dict = self._c_dict
            xmlDictReference(self._c_dict)
            
        if self._c_dict is NULL:
            self._c_dict = result.dict
            xmlDictReference(self._c_dict)
        return result
    
# globally shared parser
cdef Parser theParser
theParser = Parser()
    
def XML(text):
    cdef xmlDoc* c_doc
    c_doc = theParser.parseDoc(text)
    return _elementTreeFactory(c_doc).getroot()
