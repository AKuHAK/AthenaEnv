// {"name": "Text editor", "author": "Daniel Santos", "version": "06142023","file": "texed.js"}

var text = ""; // Armazena o texto digitado pelo usu�rio
var cursorX = 0; // Posi��o X do cursor
var cursorY = 0; // Posi��o Y do cursor

var mode = "text"; // Modo atual do editor ("text" ou "command")
var command = ""; // Comando digitado pelo usu�rio

const VK_BACKSPACE = 7;
const VK_ENTER = 10;

const VK_ALT_C = -126;
const VK_FUNCTION = 0;
const VK_ACTION = 27;
const VK_RIGHT = 41;
const VK_LEFT = 42;
const VK_DOWN = 43;
const VK_UP = 44;

const canvas = Screen.getMode();

const def_font = new Font("default");
def_font.scale = 0.6f;

var curFileName = "";

var showF1Text = true;

// Fun��o para desenhar o editor na tela
function drawEditor() {
    Screen.clear(); // Limpa a tela
  
    // Divide o texto em linhas usando a quebra de linha como separador
    var lines = text.split("\n");
  
    // Desenha cada linha na tela
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var linePosY = i * 16; // Posi��o Y da linha em pixels
      def_font.print(0, linePosY, line);
    }
  
    // Desenha a barra inferior
    def_font.print(0, canvas.height - 30, "Mode: " + mode + " | Command: " + command);
  
    // Calcula a posi��o X do cursor com base no tamanho da linha atual
    var currentLine = lines[cursorY];
    var cursorPosX = def_font.getTextSize(currentLine.substring(0, cursorX)).width;
  
    // Calcula a posi��o Y do cursor em pixels
    var cursorPosY = cursorY * 16;
  
    // Desenha o cursor na posi��o atual
    var cursorChar = "|"; // Caractere usado para representar o cursor
    def_font.print(cursorPosX, cursorPosY, cursorChar);

    if(showF1Text) {
        def_font.print((canvas.width/2)-def_font.getTextSize("Press F1 to enter on help menu.").width/2, (canvas.height/2)-13, "Press F1 to enter on help menu.");
    }
  
    Screen.flip(); // Atualiza a tela
  }
  
  // Fun��o para remover um caractere na posi��o atual do cursor
  function removeCharacter() {
    // Divide o texto em linhas usando a quebra de linha como separador
    var lines = text.split("\n");
  
    // Verifica se a posi��o do cursor est� dentro dos limites v�lidos
    if (cursorY >= 0 && cursorY < lines.length) {
      var line = lines[cursorY];
  
      // Verifica se a posi��o X do cursor est� dentro dos limites v�lidos
      if (cursorX > 0 && cursorX <= line.length) {
        // Remove o caractere na posi��o atual do cursor
        lines[cursorY] = line.substring(0, cursorX - 1) + line.substring(cursorX);
  
        // Move o cursor para a esquerda
        cursorX--;
      }
    }
  
    // Atualiza o texto com as linhas modificadas
    text = lines.join("\n");
  }

var oldpad = undefined;
var pad = undefined;

var charCode = 0;
var oldCharCode = 0;

// Fun��o para processar a entrada do usu�rio
function processInput() {
    oldpad = pad;
    pad = Pads.get(); // Obt�m o estado do gamepad na porta 0

    oldCharCode = charCode;
    charCode = Keyboard.get();

    if(oldCharCode == VK_ACTION && charCode == VK_FUNCTION + 1) {
        while (true) {
            Screen.clear();
            oldCharCode = charCode;
            charCode = Keyboard.get();

            if(oldCharCode == VK_ACTION && charCode == VK_FUNCTION + 1) {
                break;
            }

            def_font.print(0, 0, "Press Alt+C to switch between command and text mode.");
            def_font.print(0, 16, "Press F1 to enter and exit help.");
            def_font.print(0, 48, "Commands:");
            def_font.print(0, 64, "new - Creates a new blank file");
            def_font.print(0, 80, "open file_name.txt - Open file");
            def_font.print(0, 96, "saveas file_name.txt - Save to new file");
            def_font.print(0, 112, "save - Saves the current file");
            Screen.flip();
        }
    }

    if(charCode !== 0) {
        console.log("Old char: " + oldCharCode);
        console.log("Char code: " + charCode);
    }
  
    // Verifica se est� no modo de texto
    if (mode === "text") {
      // Converte o c�digo ASCII do caractere para uma string

      if (charCode === VK_ALT_C) {
        mode = "command";
        command = "";
      } else if (oldCharCode == VK_ACTION && charCode == VK_UP) {
        cursorY--;
      } else if (oldCharCode == VK_ACTION && charCode == VK_DOWN) {
        cursorY++;
      } else if (oldCharCode == VK_ACTION && charCode == VK_LEFT) {
        if (cursorX > 0) {
          cursorX--;
        } else if (cursorY > 0) {
          cursorY--;
          var lines = text.split("\n");
          cursorX = lines[cursorY].length;
        }
      } else if (oldCharCode == VK_ACTION && charCode == VK_RIGHT) {
        var lines = text.split("\n");
        if (cursorX < lines[cursorY].length) {
          cursorX++;
        } else if (cursorY < lines.length - 1) {
          cursorY++;
          cursorX = 0;
        }
      } else if (charCode === VK_BACKSPACE) {
        if (cursorX > 0) {
          removeCharacter();
        } else if (cursorY > 0) {
          var lines = text.split("\n");
          if (lines[cursorY] === "" && cursorY !== 0) {
            // Remove a linha vazia
            lines.splice(cursorY, 1);
  
            // Move o cursor para a linha anterior
            cursorY--;
            cursorX = lines[cursorY].length;
  
            // Atualiza o texto com as linhas modificadas
            text = lines.join("\n");
          } else {
            // Remove o salto de linha
            var currentLine = lines[cursorY];
            var prevLine = lines[cursorY - 1];
  
            lines[cursorY - 1] = prevLine + currentLine;
            lines.splice(cursorY, 1);
  
            // Move o cursor para a posi��o correta
            cursorY--;
            cursorX = prevLine.length;
  
            // Atualiza o texto com as linhas modificadas
            text = lines.join("\n");
          }
        }
      } else if (charCode === VK_ENTER) {
        // Insere uma quebra de linha na posi��o atual do cursor
        var lines = text.split("\n");
        var line = lines[cursorY];
        lines[cursorY] = line.substring(0, cursorX) + "\n" + line.substring(cursorX);
  
        // Move o cursor para a pr�xima linha
        cursorY++;
        cursorX = 0;
  
        // Atualiza o texto com as linhas modificadas
        text = lines.join("\n");
      } else if (charCode !== 0 && charCode !== VK_ACTION) {
        var char = String.fromCharCode(charCode);
  
        // Insere o caractere na posi��o atual do cursor
        var lines = text.split("\n");
        var line = lines[cursorY];
        lines[cursorY] = line.substring(0, cursorX) + char + line.substring(cursorX);
  
        // Move o cursor para a direita
        cursorX++;
  
        // Atualiza o texto com as linhas modificadas
        text = lines.join("\n");
      }

    } else if (mode === "command") {
      // Verifica se o usu�rio pressionou o bot�o Triangle para voltar ao modo de texto
      if (charCode === VK_ALT_C) {
        mode = "text";
      } else if (charCode === VK_ENTER) {
        if (command.startsWith("saveAs ")) {
            var fileName = command.substring(5); // Obt�m o nome do arquivo a ser salvo
            saveToFile(fileName); // Chama a fun��o para salvar o arquivo
        } else if (command == "save") {
            saveToFile(curFileName); // Chama a fun��o para salvar o arquivo
        } else if (command.startsWith("open ")) {
            var fileName = command.substring(5); // Obt�m o nome do arquivo a ser salvo
            openFile(fileName); // Chama a fun��o para salvar o arquivo
            cursorX = 0;
            cursorY = 0;
        }  else if (command == "new") {
            text = "";
            cursorX = 0;
            cursorY = 0;
        }

        command = ""; // Limpa o comando
      } else if (charCode === VK_BACKSPACE) {
        command = command.slice(0, -1);
      } else if (charCode !== 0) {
        var char = String.fromCharCode(charCode);
        command += char;
      }
    }
}


// Fun��o para salvar o texto em um arquivo
function saveToFile(fileName) {
    var file = std.open(fileName, "w");
    file.write(Uint8Array.from(Array.from(text).map(letter => letter.charCodeAt(0))).buffer, 0, text.length);
    file.close();
}

function openFile(fileName) {
    cursorX = 0;
    cursorY = 0;
	curFileName = fileName;
    var file = std.open(fileName, "r");
    text = file.readAsString();
    file.close();
}

// Loop principal do editor
function mainLoop() {
  os.setInterval(() => {    
    processInput(); // Processa a entrada do usu�rio
    drawEditor(); // Desenha o editor na tela
  }, 16);
}

// Inicializa o editor
function initializeEditor() {
  IOP.loadDefaultModule(IOP.keyboard);
  Keyboard.init(); // Inicializa o teclado

  // Configura as propriedades do editor
  cursorX = 0;
  cursorY = 0;
  text = "";

  // Inicia o loop principal do editor
  mainLoop();
}

initializeEditor();

os.setTimeout(() => {   
    showF1Text = false;
}, 5000);
