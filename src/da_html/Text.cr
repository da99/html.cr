
module DA_HTML
  class Text

    getter tag_text : String
    getter index    = 0

    def initialize(n : Myhtml::Node, @index)
      @tag_text = n.tag_text
    end # === def

    def empty?
      @tag_text.strip.empty?
    end

    def tag_name
      "-text"
    end

  end # === struct Text
end # === module DA_HTML