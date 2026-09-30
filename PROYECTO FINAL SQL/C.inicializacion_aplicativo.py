import tkinter as tk

from script_interfaz_voluntariado import App


def iniciar_aplicativo(root=None):
    iniciar_bucle = root is None
    if root is None:
        root = tk.Tk()
    App(root)
    if iniciar_bucle:
        root.mainloop()


if __name__ == "__main__":
    iniciar_aplicativo()
