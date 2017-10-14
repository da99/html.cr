

module DA_HTML

  module DIV

    macro div(*args, **attrs, &blok)
      io.render_tag!("div") {
        {% unless args.empty? %}
          io.render_id_class! {{*args}}
        {% end %}
        {% for k,v in attrs %}
          div_{{k}}({{v}})
        {% end %}

        div_render {
          {{blok.body}}
        }
      }
    end # === macro div

    def div_render
      yield
    end # === def div_render

  end # === module DIV

end # === module DA_HTML
