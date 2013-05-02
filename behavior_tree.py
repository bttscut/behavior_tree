#coding=utf-8
import xml.etree.ElementTree as ET

TYPES_ = {
    'int': int,
    'float': float,
    'str': unicode,
}

def make_root(root):
    pass

def make_selector(node):
    funcs = [parse_node(child) for child in node[0]]
    def selector(robot):
        for func in funcs:
            result = func(robot)
            if result:
                return True
        return False
    return selector

def make_sequence(node):
    funcs = [parse_node(child) for child in node[0]]
    def sequence(robot):
        for func in funcs:
            result = func(robot)
            if not result:
                return False
        return True
    return sequence

def make_parallel(node):
    funcs = [parse_node(child) for child in node[0]]
    def parallel(robot):
        results = []
        for func in funcs:
            result = func(robot)
            results.append(result)
        return any(results)
    return parallel

def make_alternate(node):
    funcs = [parse_node(child) for child in node[0]]
    def alternate(robot):
        i = 0
        while True:
            func = funcs[i]
            yield func(robot)
            i += 1
            if i >= len(funcs):
                i = 0
    return alternate

def extract_keywords(node):
    attrib = node.attrib
    keywords = {}
    for key, value in attrib.iteritems():
        if key == 'Class':
            continue
        if key.startswith('_'):
            continue
        type_key_name = '_' + key + 'Type'
        type_name = attrib[type_key_name]
        type_ = TYPES_[type_name]
        keywords[key.lower()]  = type_(value)
    return keywords

def make_condition(node, name):
    func_name = name.lower()
    keywords = extract_keywords(node)
    def condition(robot):
        method = getattr(robot, func_name)
        return method(**keywords)
    condition.func_name = func_name
    return condition

def make_action(node, name):
    func_name = name.lower()
    keywords = extract_keywords(node)
    def action(robot):
        method = getattr(robot, func_name)
        return method(**keywords)
    action.func_name = func_name
    return action


def parse_composites(node, name):
    if name == 'Selector':
        return make_selector(node)
    if name == 'Sequence':
        return make_sequence(node)
    if name == 'Parallel':
        return make_parallel(node)
    if name == 'Alternate':
        return make_alternate(node)
    raise Exception('Unknown Composite Node', name)

def make_loot(node):
    child = node[0][0]
    func = parse_node(child)
    count = int(node.attrib['Count'])
    def loop(robot):
        return all(func(robot) for i in xrange(count))
    return loop

def parse_decorators(node, name):
    if name == 'Loop':
        return make_loot(node)
    raise Exception('Unknown Decorator Node', name)

def parse_node(node):
    class_name = node.attrib['Class']
    _, node_type, node_name = class_name.split('.')
    if node_type == 'Composites':
        return parse_composites(node, node_name)
    if node_type == 'Decorators':
        return parse_decorators(node, node_name)
    if node_type == 'Conditions':
        return make_condition(node, node_name)
    if node_type == 'Actions':
        return make_action(node, node_name)
    raise Exception('Unknown Type Node', node_type)

def parse_xml(path):
    tree = ET.parse(path)
    root = tree.getroot()
    root = root[0]
    return parse_node(root[0][0])


if __name__ == '__main__':
    parse_xml('test.xml')


