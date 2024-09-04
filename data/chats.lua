local science = {
  messages = { {
      content = "why is the sky blue",
      role = "user"
    }, {
      content = "The short answer: The sky appears blue because of a phenomenon called scattering, where shorter (blue) wavelengths of light are scattered more than longer (red) wavelengths by tiny molecules of gases in the Earth's atmosphere.\n\nHere's a more detailed explanation:\n\n1. **Light from the sun**: When sunlight enters the Earth's atmosphere, it contains all the colors of the visible spectrum, which we perceive as white light.\n2. **Scattering**: As this light travels through the atmosphere, it encounters tiny molecules of gases like nitrogen (N2) and oxygen (O2). These molecules are much smaller than the wavelength of light, so they scatter shorter wavelengths more effectively.\n3. **Blue light is scattered more**: The blue wavelengths of light (~450-495 nanometers) are scattered more efficiently than longer wavelengths, such as red light (~620-750 nanometers). This is because the size of the molecules is comparable to the wavelength of blue light, making them more effective scatterers.\n4. **Red light continues to travel**: The longer wavelengths of light, like red and orange, have a shorter scattering cross-section due to their larger size relative to the molecules. As a result, they continue to travel in straight lines with less interaction from the atmosphere.\n5. **Our perception**: When we look at the sky, our eyes perceive the scattered blue light as the dominant color, while the unscattered red and orange light appears as a more muted tone, often referred to as \"yellow\" or \"golden.\" This is why the sky usually appears blue during the daytime, when the sun is overhead.\n6. **Atmospheric conditions**: Factors like pollution, dust, water vapor, and other particles in the air can affect the scattering process, making the sky appear more hazy or changing its apparent color.\n\nRemember, this is a simplified explanation of the complex processes involved in why the sky appears blue. If you'd like to dive deeper into the science behind light scattering, I'm happy to provide more information!",
      role = "assistant"
    } },
  model = "llama3",
  opts = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5,
    num_ctx = 2048,
    num_keep = 24,
    num_predict = 128,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    seed = 0,
    stop = { '"<|start_header_id|>"', '"<|end_header_id|>"', '"<|eot_id|>"' },
    temperature = 0.8,
    tfs_z = 1,
    top_k = 40,
    top_p = 40
  },
  stream = false
}
local knock_knock = {
  messages = { {
      content = "tell me a good knock knock joke. Waut for my response before moving on with the joke.",
      role = "user"
    }, {
      content = "I've got one!\n\nKnock, knock!\n\n(Waiting for your response...)",
      role = "assistant"
    }, {
      content = "whos there?",
      role = "user"
    }, {
      content = "Cows go!",
      role = "assistant"
    }, {
      content = "Cows go who?",
      role = "user"
    }, {
      content = 'No, cows go "moo"!',
      role = "assistant"
    } },
  model = "llama3",
  opts = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5,
    num_ctx = 2048,
    num_keep = 24,
    num_predict = 128,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    seed = 0,
    stop = { '"<|start_header_id|>"', '"<|end_header_id|>"', '"<|eot_id|>"' },
    temperature = 0.8,
    tfs_z = 1,
    top_k = 40,
    top_p = 40
  },
  stream = false
}local OOP = {
  messages = { {
      content = "explain OOP using examples written in Rust",
      role = "user"
    }, {
      content = "\nObject-Oriented Programming (OOP) is a programming paradigm that organizes software design around data and behavior. In OOP, objects are instances of classes that represent real-world entities or concepts. Objects have their own state, which includes the values of their attributes, and can perform actions, which are typically methods that operate on the object's state.\n\nHere are some examples of how to implement OOP in Rust:\n\n1. Encapsulation:\nIn this example, we create a class called `Person` with two attributes: `name` and `age`. We also define a method called `greet`, which prints a greeting message using the person's name. The `name` attribute is private, so it can only be accessed through the `greet` method.\n```\nstruct Person {\n    name: String,\n    age: u32,\n}\n\nimpl Person {\n    fn new(name: &str, age: u32) -> Self {\n        Person { name, age }\n    }\n\n    fn greet(&self) {\n        println!(\"Hello, my name is {} and I'm {} years old\", self.name, self.age);\n    }\n}\n```\n1. Inheritance:\nIn this example, we create a class called `Student` that inherits from the `Person` class. The `Student` class has one additional attribute: `grade`. We also define a method called `get_grade`, which returns the student's grade.\n```\nstruct Person {\n    name: String,\n    age: u32,\n}\n\nimpl Person {\n    fn new(name: &str, age: u32) -> Self {\n        Person { name, age }\n    }\n\n    fn greet(&self) {\n        println!(\"Hello, my name is {} and I'm {} years old\", self.name, self.age);\n    }\n}\n\nstruct Student {\n    grade: u8,\n}\n\nimpl Student {\n    fn new(grade: u8) -> Self {\n        Student { grade }\n    }\n\n    fn get_grade(&self) -> u8 {\n        self.grade\n    }\n}\n```\n1. Polymorphism:\nIn this example, we create a class called `Shape` with two subclasses: `Circle` and `Square`. The `Shape` class has an attribute called `color`, which is inherited by the subclasses. We also define a method called `area`, which returns the area of the shape, but is implemented differently for each subclass.\n```\nstruct Shape {\n    color: String,\n}\n\nimpl Shape {\n    fn new(color: &str) -> Self {\n        Shape { color }\n    }\n\n    fn area(&self) -> u32 {\n        0\n    }\n}\n\nstruct Circle {\n    radius: f64,\n}\n\nimpl Circle {\n    fn new(radius: f64) -> Self {\n        Circle { radius }\n    }\n\n    fn area(&self) -> f64 {\n        std::f64::consts::PI * self.radius * self.radius\n    }\n}\n\nstruct Square {\n    side_length: f64,\n}\n\nimpl Square {\n    fn new(side_length: f64) -> Self {\n        Square { side_length }\n    }\n\n    fn area(&self) -> f64 {\n        self.side_length * self.side_length\n    }\n}\n```",
      role = "assistant"
    } },
  model = "codellama:13b",
  opts = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5,
    num_ctx = 2048,
    num_keep = 24,
    num_predict = 128,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    rope_frequency_base = 1000000,
    seed = 0,
    stop = { '"[INST]"', '"[/INST]"', '"<<SYS>>"', '"<</SYS>>"' },
    temperature = 0.8,
    tfs_z = 1,
    top_k = 40,
    top_p = 40
  },
  stream = false
}local test = {
  messages = { {
      content = "explain this lua function: \n[[\n--[[ Takes the formatted tables from the config buffer and assigns their new values to the model options\nbefore remounting the current session and closing the config editor ]]\nM.change_config = function (current_buffer)\n    if current_buffer ~= M.config_buf.bufnr then return end\n\n    local new_opts = M.read_params()\n    API.params.opts = new_opts[1]\n    API.extra_opts = new_opts[2]\n    API.update_opts()\n\n    M.config_buf:unmount()\n    plugin.popup:show()\n    plugin.input:show()\n    if M.layout_shown then\n        plugin.layout:show()\n    end\n\n    M.update_window_selection()\n    plugin.set_keymaps()\n    print(vim.inspect(API.params))\nend\n]]",
      role = "user"
    }, {
      content = "This is a Lua function that appears to be part of a larger program or module. It takes a single argument, `current_buffer`, and returns nothing. The function seems to be responsible for updating the state of the program after changes have been made to a configuration file.\n\nThe first step in the function is to check if the current buffer is equal to a buffer named `M.config_buf.bufnr`. If it's not, the function returns immediately without taking any further action. This is likely a safety measure to ensure that only changes made to the correct buffer are processed.\n\nIf the current buffer is the correct one, the function then reads the new values from the configuration file using `M.read_params()`. It appears that these values are stored in an array called `new_opts`, with two elements: `new_opts[1]` contains a table of options for the model, and `new_opts[2]` contains extra options.\n\nThe function then assigns the new option values to two variables named `API.params.opts` and `API.extra_opts`. It's not clear what these variables are or where they come from, but it seems that they represent some kind of state or configuration for the program.\n\nAfter updating the option values, the function calls a method called `API.update_opts()` to update the state of the program based on the new options.\n\nFinally, the function unmounts the current buffer and shows a popup, input, and layout (if they're present) using functions from the `plugin` module. It also updates the window selection and sets keymaps using functions from the same module. The function then prints the new option values to the console using `vim.inspect()`.\n\nOverall, this function seems to be responsible for updating the program's state after changes have been made to a configuration file. It may be part of a larger framework or library that provides a user interface for configuring and interacting with the program.",
      role = "assistant"
    }, {
      content = "what about this function which is called in the previously provided function: \n[[\n-- Reads the config buffer and transforms to a string before loading and returning the strings as seperate table values\nM.read_params = function ()\n    local content = vim.api.nvim_buf_get_lines(M.config_buf.bufnr, 0, -1, false)\n    local str = table.concat(content, '\\n')\n\n    local t = {}\n    local current_table = \"\"\n    local depth = 0\n\n    for line in str:gmatch(\"[^\\r\\n]+\") do\n        if line:match(\"{\") then\n            if depth == 0 then\n                current_table = \"\"\n            end\n            depth = depth + 1\n        end\n\n        if depth > 0 then\n            current_table = current_table .. line .. \"\\n\"\n        end\n\n        if line:match('}') then\n            depth = depth - 1\n            if depth == 0 then\n                table.insert(t, current_table)\n            end\n        end\n    end\n\n    t[1] = load('return ' .. t[1])()\n    t[2] = load('return ' .. t[2])()\n\n    return t\nend\n]]",
      role = "user"
    }, {
      content = "This is another Lua function that appears to be part of the same program or module. It is called by the previously provided function, and takes no arguments. The function seems to be responsible for reading the contents of a configuration buffer and transforming them into separate string values.\n\nThe first step in the function is to retrieve the contents of the config buffer using `vim.api.nvim_buf_get_lines()`. This function retrieves all lines in the buffer, starting from line 0 and going through the last line. The resulting table of strings is then concatenated into a single string using `table.concat()` with the newline character (`\\n`) as the separator.\n\nThe next step is to parse this string and extract separate values for each table element. This is done by iterating over each line in the string using a regular expression matcher, where each match represents a single line in the buffer. The function keeps track of the current table depth using the `depth` variable, which is initialized to 0.\n\nWhenever the depth changes from 0 to 1, it means that a new table has started. In this case, the current table string (`current_table`) is set to an empty string. If the depth is greater than 0, it means that we are still inside a table, so the current line is added to the `current_table` string along with a newline character.\n\nWhenever the depth changes from 1 to 0, it means that a table has ended. In this case, the `current_table` string is inserted into an array called `t`, and then the `load()` function is used to transform the string into a Lua table. The resulting table is then returned as one of the elements in the `t` array.\n\nFinally, the function returns the `t` array, which contains the two separate string values that were extracted from the config buffer.",
      role = "assistant"
    } },
  model = "codellama:13b",
  opts = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5,
    num_ctx = 2048,
    num_keep = 24,
    num_predict = 128,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    rope_frequency_base = 1000000,
    seed = 0,
    stop = { '"[INST]"', '"[/INST]"', '"<<SYS>>"', '"<</SYS>>"' },
    temperature = 0.8,
    tfs_z = 1,
    top_k = 40,
    top_p = 40
  },
  stream = false
}local meditations = {
  messages = { {
      content = "quote Meditations",
      role = "user"
    }, {
      content = "A great choice!\n\nThe Meditations is a philosophical work written by the ancient Greek philosopher Marcus Aurelius in 170-180 AD. It's a collection of personal thoughts, reflections, and musings on Stoic philosophy.\n\nHere are some quotes from The Meditations:\n\n1. **The universe is change; our life is only a series of events.** (Book 4, Section 3)\n2. **You have power over your mind - not outside events.** (Book 4, Section 22)\n3. **The impediment to action advances action. What stands in the way becomes the way.** (Book 4, Section 15)\n4. **Do every act as if it were your last.** (Book 2, Section 11)\n5. **The universe is not a collection of distinct objects, but a continuum.** (Book 6, Section 30)\n6. **When you are troubled by anything, turn to yourself and look inwardly; there is an answer in yourself as soon as you know how to question yourself properly.** (Book 4, Section 32)\n7. **The universe is governed by reason, and so is the human mind.** (Book 6, Section 38)\n\nThese quotes give you a glimpse into the Stoic wisdom and introspective nature of Marcus Aurelius' Meditations.",
      role = "assistant"
    } },
  model = "llama3:latest",
  opts = {
    mirostat = 0,
    mirostat_eta = 0.1,
    mirostat_tau = 5,
    num_ctx = 2048,
    num_keep = 24,
    num_predict = 128,
    repeat_last_n = 64,
    repeat_penalty = 1.1,
    rope_frequency_base = 1000000,
    seed = 0,
    stop = { '"<|start_header_id|>"', '"<|end_header_id|>"', '"<|eot_id|>"' },
    temperature = 0.8,
    tfs_z = 1,
    top_k = 40,
    top_p = 40
  },
  stream = false
}