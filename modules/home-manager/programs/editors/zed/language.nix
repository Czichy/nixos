{
  programs.zed-editor.userSettings = {
    agent = {
      default_model = {
        model = "claude-opus-4-6";
        provider = "anthropic";
      };
      dock = "right";
          inline_assistant_model = {
        model = "claude-opus-4-6";
        provider = "anthropic";
      };
      model_parameters = [];
    };
    #| AI & Assistant Features
    # assistant = {
    #   version = "2";
    #   enabled = true;
    #   button = true;
    #   dock = "bottom";
    #   default_width = 640;
    #   default_height = 320;
    #   default_model = {
    #     provider = "ollama";
    #     model = "qwen2.5-coder:latest";
    #   };
    # };
    language_models = {
      anthropic = {
            available_models = [
              {
                name = "claude-opus-4-6";
                max_tokens = 2000000;
              }
            ];
      api_url = "https://api.anthropic.com";
    };
      google = {
        available_models = [
          {
            name = "gemini-2.5-pro-exp-03-25";
            display_name = "Gemini 2.5 Pro Exp";
            max_tokens = 1000000;
          }
        ];
      };
      ollama = {
        api_url = "http://localhost:11434";
        low_speed_timeout_in_seconds = 60;
      };
      openai = {
        version = "1";
        api_url = "https://api.openai.com/v1";
        low_speed_timeout_in_seconds = 600;
      };
    };

    #| Language Integrations
    enable_language_server = true;
    language_servers = ["..."];
    languages = {};
    jupyter.enabled = true;
    code_actions_on_format = {};
  };
}
