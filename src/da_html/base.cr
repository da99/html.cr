
module DA_HTML

  module Base_Class

  end # === module Base_Class

  module Base

    macro if_not_nil(name, &blok)
      %x = {{name}}
      if %x
        {{blok.body}}
      end
    end

    macro included
      extend ::DA_HTML::Base_Class
    end

    macro to_html(*args, &blok)
      {{@type}}.new({{*args}}).to_html {{blok}}
    end

    protected getter io = IO::Memory.new
    @is_partial = false
    @tags = Deque(Symbol).new

    def initialize
    end # === def initialize

    def initialize(page : DA_HTML::Base)
      @io = page.io
      @is_partial = true
    end # === def initialize

    def is_partial?
      @is_partial
    end

    # NOTE: returns nil if page is a partial (i.e. .new(Some_Page))
    def to_html
      with self yield self
      self.to_html unless is_partial?
    end

    def to_html
      @io.to_s
    end

    def raw_id_class!(x : String)
      id      = Deque(Char).new
      class_  = nil
      classes = Deque(Deque(Char)).new
      is_writing_to = :none
      x.each_char { |c|
        case c
        when '#'
          is_writing_to = :id
        when '.'
          is_writing_to = :class
          if class_ && !class_.empty?
            classes.push class_
          end
          class_ = Deque(Char).new
        when 'a'..'z', '0'..'9', '_'
          case is_writing_to
          when :id
            id.push c
          when :class
            if class_
              class_.push c
            end
          else
            raise Error.new("Invalid id/class: #{x.inspect}")
          end
        else
          raise Error.new("Invalid char for id/class: #{c.inspect} in #{x.inspect}")
        end
      }
      if class_ && !class_.empty?
        classes.push class_
        class_ = nil
      end

      if !id.empty?
        raw! %[ id="]
        id.each { |c| raw! c }
        raw! '"'
      end
      if !classes.empty?
        raw! %[ class="]
        classes.each_with_index { |klass, i|
          raw! ' ' if i != 0
          klass.each { |c| raw! c }
        }
        raw! '"'
      end
      self
    end # === def write_id_class

    def raw!(*raws)
      raws.each { |s| @io << s }
      self
    end # === def raw!

    def raw!
      yield @io
      self
    end

    def raw_attr!(k : Symbol, v : String)
      raw!(' ') << k << '=' << '"' << DA_HTML_ESCAPE.escape(v) << '"'
      self
    end # === def raw_attr!

    def raw_attr!(k : Symbol, v : Deque(String))
      raw!(' ') << k << '=' << '"'
      v.each_with_index { |x, i|
        raw! ' ' if i > 0
        raw! DA_HTML_ESCAPE.escape(x)
      }
      raw!('"')
      self
    end # === def raw_attr!

    def <<(x : Symbol | String | Char)
      raw! x
    end

    def open_tag(tag_name : Symbol)
      @tags.push tag_name
      raw! { |io|
        io << '<' << tag_name
        with self yield self
        io << '>'
      }
    end # === def open_tag

    def close_tag(tag_name : Symbol)
      old_tag = @tags.pop
      if old_tag != tag_name
        raise Error.new("Leaving tag #{old_tag.inspect} but expecting #{tag_name.inspect}")
      end
      raw!('<') << '/' << tag_name << '>'
      self
    end # === def close_tag

    def html(args = nil)
      if !args
        raw! %[<html lang="en">]
        with self yield
        raw! %[</html>]
      else
        open_and_close_tag("html", args) {
          with self yield
        }
      end
    end # === def html

    def doctype!
      raw! "<!DOCTYPE html>"
    end # === def doctype

    def text(raw : String)
      @io << DA_HTML_ESCAPE.escape(raw)
    end # === def text

    def raw_attrs!(*args, **attrs)
      args.each { |a|
        raw! ' '
        case a.size
        when 1
          raw! { |io| a.first.to_s(io) }
        when 2
          raw! { |io|
            a.first.to_s(io)
            io << '=' << '"'
            io << DA_HTML_ESCAPE.escape(a.last)
            io << '"'
          }
        else
          raise Error.new("Invalid attribute #{name.inspect}: #{a.inspect}")
        end
      }
    end # === def raw_attrs!

    def raw_tag!(name : Symbol, *args, **attrs)
      @tags.push name

      result = with self yield self
      case result
      when String
        text result
      end
      @io << '<' << '/' << name << '>'
      @tags.pop
      self
    end # === def open_and_close_tag

    def head(*args)
      HEAD.new(self, *args).to_html {
        with self yield self
      }
    end # === def head

    {% for x in %w[body p div span title strong a] %}
      def {{x.id}}(*args, **attrs)
        {{x.upcase.id}}.new(self, *args, **attrs).to_html {
          with self yield self
        }
      end # === def {{x.id}}
    {% end %}

  end # === module Base

end # === module DA_HTML