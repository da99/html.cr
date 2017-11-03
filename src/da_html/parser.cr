
require "xml"

{% `mkdir -p tmp` %}
{% `rm -f tmp/da_html.tmp.*` %}
{% `touch tmp/da_html.tmp.tags` %}
{% `touch tmp/da_html.tmp.attrs` %}

require "./parser/exception"
require "./parser/template"

module DA_HTML

  module Parser

    SEGMENT_ATTR_ID    = /([a-z0-9\_\-]{1,15})/
    SEGMENT_ATTR_CLASS = /[a-z0-9\ \_\-]{1,50}/
    SEGMENT_ATTR_HREF  = /[a-z0-9\ \_\-\/\.]{1,50}/

    @is_fin = false
    @origin : String = ""
    @root   : XML::Node

    getter file_dir : String
    getter io       : IO::Memory = IO::Memory.new

    def initialize(file : String, @file_dir)
      @origin = DA_HTML.file_read!(@file_dir, file)
      @root   = XML.parse_html(@origin, XML::HTMLParserOptions::NOBLANKS | XML::HTMLParserOptions::PEDANTIC)
    end # === def initialize

    def initialize(@root, @file_dir)
    end # === def initialize

    def initialize(@root, @io, @file_dir)
    end # === def initialize

    macro def_tags(*args, &blok)
      {% for name in args %}
        def_tag({{name}}) {{blok}}
      {% end %}
    end # === macro def_tags

    macro def_tag(name, &blok)
      {% `bash -c  "echo #{name.id} >> tmp/da_html.tmp.tags"` %}
        {% if blok %}
          def {{name.id}}({{blok.args.first}} : XML::Node)
            {{blok.body}}
          end
        {% else %}
          def {{name.id}}(node : XML::Node)
            node
          end
        {% end %}
    end # === macro def_tag

    macro def_attr(tag_name, name, pattern)
      {% pattern_name = "PATTERN_ATTR_#{tag_name.id.upcase.gsub(/[^0-9A-Z\_]/, "_")}_#{name.id.upcase.gsub(/[^A-Z0-9]/, "_")}".id %}
      {{pattern_name}} = /^(#{{{pattern}}})$/

      {% `bash -c  "echo #{tag_name.id} #{name.id} >> tmp/da_html.tmp.attrs"` %}
      def {{tag_name.id}}_{{name.id}}(node : XML::Node, attr : XML::Node)
        content = attr.content
        case
        when content.is_a?(String) && content =~ {{pattern_name}}
          attr.content = DA_HTML_ESCAPE.escape(attr.content)
        else
          raise Invalid_Attr_Value.new("{{tag_name.id}} {{name.id}}:  #{content.inspect}")
        end

        attr
      end
    end # === macro attr

    macro def_attr(tag_name, name, &blok)
      {% `bash -c  "echo #{tag_name.id} #{name.id} >> tmp/da_html.tmp.attrs"` %}
      {% if blok %}
        def {{tag_name.id}}_{{name.id}}(
          {% if !blok.args.empty? %}
            {{blok.args.first}} : XML::NODE, {{blok.args.last}} : XML::NODE
          {% end %}
        )
          {{blok.body}}
        end
      {% else %}
        def_attr({{tag_name}}, {{name}}, SEGMENT_ATTR_{{name.id.upcase.gsub(/[^A-Z0-9]/, "_")}})
      {% end %}
    end # === macro attr

    macro finish_def_html!
      def render_element_node(node : XML::Node)
        name = node.name
        {% if !`bash -c "cat tmp/da_html.tmp.tags 2>/dev/null || :"`.strip.empty? %}
        case name
          {% for x in system("bash -c \"cat tmp/da_html.tmp.tags\"").split("\n").reject { |x| x.empty? } %}
          when "{{x.id}}"
            return {{x.id}}(node)
          {% end %}
        end # === node.name
        {% end %}
        raise Exception.new("Element not allowed: #{node.name.inspect}")
      end # === def render_element_node

      def render_element_attribute(node : XML::Node, attr : XML::Node)
        tag_name = node.name
        name     = attr.name
        {% if !`bash -c "cat tmp/da_html.tmp.attrs 2>/dev/null || :"`.strip.empty? %}
          case
            {% for x in system("cat tmp/da_html.tmp.attrs").split("\n").reject { |x| x.empty? } %}
            {% tag_name = x.split.first %}
            {% name     = x.split.last %}
            when tag_name == "{{tag_name.id}}" && name == "{{name.id}}"
              return {{tag_name.id}}_{{name.id}}(node, attr)
            {% end %}
          end # === node.name
        {% end %}
        raise Exception.new("Attribute not allowed: #{node.name.inspect} #{attr.name.inspect}")
      end
      {% `bash -c "rm -f tmp/da_html.tmp.*"` %}
    end # === macro render(node)

    def to_html
      @root.children.each { |node|
        self.class.new(@io, node).to_html
      }
      @io.to_s
    end # === def run

    getter last_was_text : Bool = false
    def last_was_text?
      @last_was_text
    end # === def last_was_text?

    def run
      node = @root
      last_was_text = false

      case node.type
      when XML::Type::DTD_NODE
        io << node.to_s

      when XML::Type::ELEMENT_NODE
        node = render_element_node(node)
        case node
        when String
          io << node

        when XML::Node
          io << "\n"
          io.spaces
          attrs = node.attributes
          if attrs.empty?
            io << "<#{node.name}>"
          else
            io << "<#{node.name}"
            attrs.each { |a|
              new_a = render_element_attribute(node, a)
              if new_a.is_a?(XML::Node)
                io << " " << new_a.name << "=" << new_a.content.inspect
              end
            }
            io << ">"
          end
          io.indent
          node.children.each { |x|
            p = self.class.new(x, io, file_dir)
            p.to_html
            if node.children.size == 1
              last_was_text = p.last_was_text?
            end
          }

          if last_was_text || node.children.empty?
            io.de_indent
            io << "</#{node.name}>"
          else
            io << "\n"
            io.de_indent
            io.spaces
            io << "</#{node.name}>"
          end

        else
          return
        end # === case node

      when XML::Type::ATTRIBUTE_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::TEXT_NODE
        new_txt = node.to_s.strip
        io << new_txt unless new_txt.empty?
        @last_was_text = true

      when XML::Type::CDATA_SECTION_NODE
        content = node.content.strip
        return if content.empty?
        raise Exception.new("Needs to be implemented: #{node.type.inspect} #{node.content.inspect}")

      when XML::Type::ENTITY_REF_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::ENTITY_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::PI_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::COMMENT_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::DOCUMENT_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::DOCUMENT_TYPE_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::DOCUMENT_FRAG_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::NOTATION_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::HTML_DOCUMENT_NODE
        # top most root element of a doc.
        node.children.each { |x|
          self.class.new(x, io, file_dir).to_html
        }

      when XML::Type::DTD_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::ELEMENT_DECL
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::ATTRIBUTE_DECL
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::ENTITY_DECL
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::NAMESPACE_DECL
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::XINCLUDE_START
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::XINCLUDE_END
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      when XML::Type::DOCB_DOCUMENT_NODE
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      else
        raise Exception.new("Needs to be implemented: #{node.type.inspect}")

      end # === case node.type

      @is_fin = true
      self
    end # === def to_html

    def to_html
      run unless @is_fin
      io.to_s
    end # === def to_html

    def in_tree!(name)
      target = @root.parent
      while target
        return target if target.name == name
        target = target.parent
      end
      raise Exception.new("Must be inside a #{name.inspect}")
    end

  end # === module Parser

end # === module DA_HTML

module IO

  class Memory

    @indent : Int32 = 0
    def indent
      @indent += 1
    end

    def spaces
      @indent.times do |i|
        self << "  "
      end
    end

    def de_indent
      @indent -= 1
    end

  end # === class Memory

end # === module IO
