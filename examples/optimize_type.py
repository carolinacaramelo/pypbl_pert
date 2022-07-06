"""
Sample a character type and then optimize its parameters to maximize the
likelihood of the type under the prior
"""
import argparse
import torch
import numpy as np
import matplotlib.pyplot as plt

from pybpl.library import Library
from pybpl.model import CharacterModel
from pybpl.objects import CharacterType



def optimize_type(model, c, lr, nb_iter, eps, show_examples=True):
    """
    Take a character type and optimize its parameters to maximize the
    likelihood under the prior, using gradient descent

    Parameters
    ----------
    model : CharacterModel
    c : CharacterType
    lr : float
    nb_iter : int
    eps : float
    show_examples : bool

    Returns
    -------
    score_list : list of float

    """
    # round nb_iter to nearest 10
    nb_iter = np.round(nb_iter, -1)
    # get optimizable variables & their bounds
    c.train()
    params = c.parameters()
    lbs = c.lbs(eps)
    ubs = c.ubs(eps)
    # optimize the character type
    score_list = []
    optimizer = torch.optim.Adam(params, lr=lr)
    if show_examples:
        fig, axes = plt.subplots(10, 4, figsize=(4, 10))
    interval = int(nb_iter / 10)
    for idx in range(nb_iter):
        if idx % interval == 0:
            # print optimization progress
            print('iteration #%i' % idx)
            if show_examples:
                # sample 4 tokens of current type (for visualization)
                for i in range(4):
                    token = model.sample_token(c)
                    img = model.sample_image(token)
                    axes[idx//interval, i].imshow(img, cmap='Greys')
                    axes[idx//interval, i].tick_params(
                        which='both',
                        bottom=False,
                        left=False,
                        labelbottom=False,
                        labelleft=False
                    )
                axes[idx//interval, 0].set_ylabel('%i' % idx)
        # zero optimizer gradients
        optimizer.zero_grad()
        # compute log-likelihood of the token
        score = model.score_type(c)
        score_list.append(score.item())
        # gradient descent step (minimize loss)
        loss = -score
        loss.backward()
        optimizer.step()
        # project all parameters into allowable range
        with torch.no_grad():
            for param, lb, ub in zip(params, lbs, ubs):
                if lb is not None:
                    torch.max(param, lb, out=param)
                if ub is not None:
                    torch.min(param, ub, out=param)

    return score_list

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ns', required=False, type=int,
                        help="number of strokes")
    parser.add_argument('--lr', default=1e-3, type=float,
                        help='learning rate')
    parser.add_argument('--eps', default=1e-4, type=float,
                        help='tolerance for constrained optimization')
    parser.add_argument('--nb_iter', default=1000, type=int,
                        help='number of optimization iterations')
    args = parser.parse_args()

    # load the library
    lib = Library()
    # create the BPL graphical model
    model = CharacterModel(lib)

    # sample a character type
    c = model.sample_type(k=args.ns)
    print('num strokes: %i' % c.k)
    print('num sub-strokes: ', [p.nsub.item() for p in c.part_types])

    # optimize the character type that we sampled
    score_list = optimize_type(model, c, args.lr, args.nb_iter, args.eps)

    # plot log-likelihood vs. iteration
    plt.figure()
    plt.plot(score_list)
    plt.ylabel('log-likelihood')
    plt.xlabel('iteration')
    plt.show()


if __name__ == "__main__":
    main()