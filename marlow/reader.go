package marlow

import "io"
import "os"
import "log"
import "fmt"
import "bytes"
import "go/ast"
import "strings"
import "reflect"
import "net/url"
import "go/token"
import "go/parser"
import "go/format"

const (
	compilerHeader = "// Code auto-generated by marlow"
)

// Compile is responsible for reading from a source and writing the generated marlow code into a destination.
func Compile(writer io.Writer, reader io.Reader) error {
	fs := token.NewFileSet()
	packageAst, e := parser.ParseFile(fs, "", reader, parser.AllErrors)

	if e != nil {
		return e
	}

	buffered := new(bytes.Buffer)

	packageName := packageAst.Name.String()

	s := make(schema)

	// Iterate over the declarations and construct the record store from the loaded ast.
	for _, d := range packageAst.Decls {
		decl, ok := d.(*ast.GenDecl)

		// Only deal with struct type declarations.
		if !ok || decl.Tok != token.TYPE || len(decl.Specs) != 1 {
			continue
		}

		typeDecl, ok := decl.Specs[0].(*ast.TypeSpec)

		if !ok {
			continue
		}

		structType, ok := typeDecl.Type.(*ast.StructType)

		if !ok {
			continue
		}

		typeName := typeDecl.Name.String()

		for _, f := range structType.Fields.List {
			if f.Tag == nil {
				continue
			}

			tag := reflect.StructTag(strings.Trim(f.Tag.Value, "`"))
			config, err := url.ParseQuery(tag.Get("marlow"))

			if err != nil || len(f.Names) == 0 {
				continue
			}

			fieldName := f.Names[0].String()

			t, ok := s[typeName]

			if !ok {
				t = &tableSource{
					config:     make(url.Values),
					recordName: typeName,
					fields:     make(map[string]url.Values),
				}

				s[typeName] = t
			}

			if fieldName == "_" || fieldName == "table" {
				t.config = config
				continue
			}

			config.Set("type", fmt.Sprintf("%v", f.Type))
			t.fields[fieldName] = config
		}

	}

	out := goWriter{
		Logger: log.New(buffered, "", 0),
	}

	out.Println(compilerHeader)
	out.Printf("package %s", packageName)

	out.Println()

	for _, d := range s.dependencies() {
		out.Printf("import \"%s\"", d)
	}

	io.Copy(buffered, s.reader())

	formatted, e := format.Source(buffered.Bytes())

	if e != nil {
		return e
	}

	_, e = io.Copy(writer, bytes.NewBuffer(formatted))

	return e
}

// NewReaderFromFile opens the requested filename and returns an io.Reader that represents the compiled source.
func NewReaderFromFile(filename string) (io.Reader, error) {
	source, e := os.Open(filename)

	if e != nil {
		return nil, e
	}

	pr, pw := io.Pipe()

	go func() {
		defer source.Close()

		if e := Compile(pw, source); e != nil {
			pw.CloseWithError(e)
			return
		}

		pw.Close()
	}()

	return pr, nil
}
