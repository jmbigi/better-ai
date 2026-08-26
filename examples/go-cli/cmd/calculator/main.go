package main

import (
	"flag"
	"fmt"
	"os"
	"strconv"

	"github.com/example/go-cli-example/internal/calculator"
	"github.com/example/go-cli-example/internal/config"
)

func main() {
	cfg := config.Load()

	// Define commands
	addCmd := flag.NewFlagSet("add", flag.ExitOnError)
	subCmd := flag.NewFlagSet("subtract", flag.ExitOnError)
	mulCmd := flag.NewFlagSet("multiply", flag.ExitOnError)
	divCmd := flag.NewFlagSet("divide", flag.ExitOnError)

	// All commands take two float64 args
	for _, cmd := range []*flag.FlagSet{addCmd, subCmd, mulCmd, divCmd} {
		cmd.Float64("a", 0, "First operand")
		cmd.Float64("b", 0, "Second operand")
	}

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	var result float64
	var err error

	switch os.Args[1] {
	case "add":
		addCmd.Parse(os.Args[2:])
		a := addCmd.Lookup("a").Value.(flag.Getter).Get().(float64)
		b := addCmd.Lookup("b").Value.(flag.Getter).Get().(float64)
		result = calculator.Add(a, b)
	case "subtract":
		subCmd.Parse(os.Args[2:])
		a := subCmd.Lookup("a").Value.(flag.Getter).Get().(float64)
		b := subCmd.Lookup("b").Value.(flag.Getter).Get().(float64)
		result = calculator.Subtract(a, b)
	case "multiply":
		mulCmd.Parse(os.Args[2:])
		a := mulCmd.Lookup("a").Value.(flag.Getter).Get().(float64)
		b := mulCmd.Lookup("b").Value.(flag.Getter).Get().(float64)
		result = calculator.Multiply(a, b)
	case "divide":
		divCmd.Parse(os.Args[2:])
		a := divCmd.Lookup("a").Value.(flag.Getter).Get().(float64)
		b := divCmd.Lookup("b").Value.(flag.Getter).Get().(float64)
		result, err = calculator.Divide(a, b)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	case "help", "-h", "--help":
		printUsage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n", os.Args[1])
		printUsage()
		os.Exit(1)
	}

	// Output result
	if cfg.Format == "json" {
		fmt.Printf(`{"result":%g,"operation":"%s"}\n`, result, os.Args[1])
	} else {
		fmt.Printf("%g\n", result)
	}
}

func printUsage() {
	fmt.Println(`Calculator CLI - Better-AI Example

Usage:
  calculator <command> [flags]

Commands:
  add       Add two numbers
  subtract  Subtract b from a
  multiply  Multiply two numbers
  divide    Divide a by b
  help      Show this help

Flags (for all commands):
  -a float    First operand (required)
  -b float    Second operand (required)

Environment variables:
  CALCULATOR_FORMAT   Output format: text|json (default: text)
  CALCULATOR_DEBUG    Enable debug logging (default: false)

Examples:
  calculator add -a 10 -b 5
  calculator divide -a 10 -b 3
  CALCULATOR_FORMAT=json calculator multiply -a 6 -b 7
`)
}